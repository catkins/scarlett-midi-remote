import Foundation
import Combine
import Network

public enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case discovered
    case connecting
    case awaitingApproval
    case connected
    case error(String)
}

public protocol ControlServerClientProtocol {
    var statePublisher: AnyPublisher<ConnectionState, Never> { get }
    var devicePublisher: AnyPublisher<Scarlett18i20Gen2Model, Never> { get }
    var meterPublisher: AnyPublisher<[String: Double], Never> { get }
    func connect(to server: DiscoveredServer)
    func disconnect()
    func requestDeviceSnapshot()
    func setMeterUpdatesEnabled(_ enabled: Bool)
    func setMonitorMute(_ enabled: Bool)
    func setMonitorDb(_ value: Double)
    func setOutputGain(id: String, db: Double)
    func setOutputMute(id: String, enabled: Bool)
    func setMixGain(mixId: String, slotIndex: Int, db: Double)
    func setMixMute(mixId: String, slotIndex: Int, enabled: Bool)
    func setMixSolo(mixId: String, slotIndex: Int, enabled: Bool)
}

public final class ControlServerClient: ControlServerClientProtocol {
    private let queue = DispatchQueue(label: "com.example.ScarlettMidiControl.control")
    private let stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let deviceSubject = CurrentValueSubject<Scarlett18i20Gen2Model, Never>(Scarlett18i20Gen2Model())
    private let meterSubject = CurrentValueSubject<[String: Double], Never>([:])
    
    public var statePublisher: AnyPublisher<ConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    public var devicePublisher: AnyPublisher<Scarlett18i20Gen2Model, Never> { deviceSubject.eraseToAnyPublisher() }
    public var meterPublisher: AnyPublisher<[String: Double], Never> { meterSubject.eraseToAnyPublisher() }
    
    private var connection: NWConnection?
    private var keepAliveTimer: DispatchSourceTimer?
    private let framing = ProtocolFraming()
    private var inboundBuffer = Data()
    private var lastServer: DiscoveredServer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var userDisconnected = false
    private var parameters = DeviceParameterMap()
    private var meterParamIds: Set<String> = []
    private var meters: [String: Double] = [:]
    private var meterUpdatesEnabled = false
    private var meterFlushWork: DispatchWorkItem?
    /// Skip inbound echoes for IDs we just wrote so sliders don't fight the server.
    private var suppressInboundUntil: [String: Date] = [:]
    
    public var clientName: String = "Scarlett MIDI Control"
    public var clientKey: String = UUID().uuidString
    public var autoReconnect: Bool = true
    
    public init() {}
    
    public func connect(to server: DiscoveredServer) {
        queue.async { [weak self] in
            self?.connectOnQueue(to: server)
        }
    }
    
    public func disconnect() {
        queue.async { [weak self] in
            self?.userDisconnected = true
            self?.tearDown(state: .disconnected)
        }
    }
    
    public func requestDeviceSnapshot() {
        queue.async { [weak self] in
            guard let self, !self.parameters.deviceId.isEmpty else { return }
            self.sendXML(DeviceXML.subscribeMessage(deviceId: self.parameters.deviceId))
        }
    }

    public func setMeterUpdatesEnabled(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.meterUpdatesEnabled = enabled
            self.meterFlushWork?.cancel()
            self.meterFlushWork = nil
            if enabled {
                self.meterSubject.send(self.meters)
            }
        }
    }
    
    public func setMonitorMute(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            model.monitorMute = enabled
            self.deviceSubject.send(model)
            var items: [(String, String)] = []
            let flag = enabled ? "true" : "false"
            if let id = self.parameters.hardwareMuteId {
                items.append((id, flag))
            }
            self.sendItems(items)
        }
    }
    
    public func setMonitorDb(_ value: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            let clamped = self.clamp(value)
            var model = self.deviceSubject.value
            model.monitorDb = clamped
            self.deviceSubject.send(model)
            guard let id = self.parameters.hardwareGainId else { return }
            self.sendItems([(id, Self.formatDb(clamped))])
        }
    }
    
    public func setMonitorLeftDb(_ value: Double) { setMonitorDb(value) }
    public func setMonitorRightDb(_ value: Double) { setMonitorDb(value) }
    
    public func setOutputGain(id: String, db: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            guard let idx = model.outputs.firstIndex(where: { $0.id == id }) else { return }
            let clamped = self.clamp(db)
            var items: [(String, String)] = []
            let pair = self.linkedOutputIndices(around: idx, in: model.outputs)
            for i in pair {
                model.outputs[i].gainDb = clamped
                if let gainId = model.outputs[i].gainId {
                    items.append((gainId, Self.formatDb(clamped)))
                }
            }
            self.deviceSubject.send(model)
            self.sendItems(items)
        }
    }
    
    public func setOutputMute(id: String, enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            guard let idx = model.outputs.firstIndex(where: { $0.id == id }) else { return }
            var items: [(String, String)] = []
            let flag = enabled ? "true" : "false"
            let pair = self.linkedOutputIndices(around: idx, in: model.outputs)
            for i in pair {
                model.outputs[i].muted = enabled
                if let muteId = model.outputs[i].muteId {
                    items.append((muteId, flag))
                }
            }
            self.deviceSubject.send(model)
            self.sendItems(items)
        }
    }

    public func setMixGain(mixId: String, slotIndex: Int, db: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            let clamped = min(max(db, model.mixGainRange.lowerBound), model.mixGainRange.upperBound)
            let items = self.mutateMixStrips(mixId: mixId, slotIndex: slotIndex, in: &model) { strip in
                strip.gainDb = clamped
            } idSelector: { $0.gainId }
            value: { Self.formatDb(clamped) }
            self.deviceSubject.send(model)
            self.sendItems(items)
        }
    }

    public func setMixMute(mixId: String, slotIndex: Int, enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            let items = self.mutateMixStrips(mixId: mixId, slotIndex: slotIndex, in: &model) { strip in
                strip.muted = enabled
            } idSelector: { $0.muteId }
            value: { enabled ? "true" : "false" }
            self.deviceSubject.send(model)
            self.sendItems(items)
        }
    }

    public func setMixSolo(mixId: String, slotIndex: Int, enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            var model = self.deviceSubject.value
            let items = self.mutateMixStrips(mixId: mixId, slotIndex: slotIndex, in: &model) { strip in
                strip.solo = enabled
            } idSelector: { $0.soloId }
            value: { enabled ? "true" : "false" }
            self.deviceSubject.send(model)
            self.sendItems(items)
        }
    }

    @discardableResult
    private func mutateMixStrips(
        mixId: String,
        slotIndex: Int,
        in model: inout Scarlett18i20Gen2Model,
        update: (inout MixStripState) -> Void,
        idSelector: (MixStripIDs) -> String,
        value: () -> String
    ) -> [(String, String)] {
        guard let left = MixerLayout.leftMix(forMixId: mixId, in: model.mixes),
              let leftIndex = model.mixes.firstIndex(where: { $0.id == left.id }) else { return [] }
        let stereo = model.mixerSlots.indices.contains(slotIndex) && model.mixerSlots[slotIndex].stereo
        let slotIndices = MixerLayout.writeSlotIndices(
            slotIndex: slotIndex,
            stereo: stereo,
            stripCount: model.mixes[leftIndex].strips.count
        )
        var mixIndices = [leftIndex]
        if let partner = MixerLayout.partnerMix(for: model.mixes[leftIndex], in: model.mixes),
           let partnerIndex = model.mixes.firstIndex(where: { $0.id == partner.id }) {
            mixIndices.append(partnerIndex)
        }
        var items: [(String, String)] = []
        let formatted = value()
        for mixIndex in mixIndices {
            for slot in slotIndices where model.mixes[mixIndex].strips.indices.contains(slot) {
                update(&model.mixes[mixIndex].strips[slot])
                let id = idSelector(model.mixes[mixIndex].stripIDs[slot])
                if !id.isEmpty {
                    items.append((id, formatted))
                }
            }
        }
        return items
    }
    
    private func linkedOutputIndices(around index: Int, in outputs: [DeviceChannel]) -> [Int] {
        guard outputs.indices.contains(index) else { return [] }
        let channel = outputs[index]
        guard channel.stereoLinked else { return [index] }
        if !channel.stereoName.isEmpty, index + 1 < outputs.count {
            return [index, index + 1]
        }
        if channel.stereoName.isEmpty, index > 0, !outputs[index - 1].stereoName.isEmpty, outputs[index - 1].stereoLinked {
            return [index - 1, index]
        }
        return [index]
    }
    
    private func clamp(_ value: Double) -> Double {
        min(max(value, parameters.gainRange.lowerBound), parameters.gainRange.upperBound)
    }
    
    private func sendItems(_ items: [(String, String)]) {
        guard !items.isEmpty, !parameters.deviceId.isEmpty else { return }
        let until = Date().addingTimeInterval(0.75)
        for item in items {
            suppressInboundUntil[item.0] = until
        }
        sendXML(DeviceXML.setMessage(deviceId: parameters.deviceId, items: items))
    }
    
    private func connectOnQueue(to server: DiscoveredServer) {
        userDisconnected = false
        reconnectWorkItem?.cancel()
        tearDown(state: .connecting)
        lastServer = server
        
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let port = NWEndpoint.Port(rawValue: server.port) ?? 49152
        let conn = NWConnection(host: NWEndpoint.Host(server.host), port: port, using: params)
        connection = conn
        conn.stateUpdateHandler = { [weak self] newState in
            self?.queue.async {
                self?.handleConnectionState(newState)
            }
        }
        conn.start(queue: queue)
    }
    
    private func handleConnectionState(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            startReceiveLoop()
            sendClientHello()
            startKeepAlive()
            stateSubject.send(.awaitingApproval)
        case .failed(let error):
            stateSubject.send(.error(error.localizedDescription))
            scheduleReconnect()
        case .waiting(let error):
            stateSubject.send(.error(error.localizedDescription))
            scheduleReconnect()
        case .cancelled:
            if !userDisconnected, stateSubject.value != .disconnected {
                scheduleReconnect()
            }
        default:
            break
        }
    }
    
    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            self.queue.async {
                if let data, !data.isEmpty {
                    self.inboundBuffer.append(data)
                    self.processInbound()
                }
                if let error {
                    self.stateSubject.send(.error(error.localizedDescription))
                    self.scheduleReconnect()
                    return
                }
                if isComplete {
                    if !self.userDisconnected {
                        self.scheduleReconnect()
                    }
                    return
                }
                self.startReceiveLoop()
            }
        }
    }
    
    private func processInbound() {
        let frames = framing.tryParseFrames(from: &inboundBuffer)
        for xml in frames {
            handleXML(xml)
        }
    }
    
    private func handleXML(_ xml: String) {
        if xml.contains("<keep-alive") { return }
        
        if let authorised = DeviceXML.parseApprovalAuthorised(xml) {
            stateSubject.send(authorised ? .connected : .awaitingApproval)
            return
        }
        
        if xml.contains("<client-details"), DeviceXML.parseClientId(xml) != nil {
            stateSubject.send(.awaitingApproval)
        }
        
        if xml.contains("<device-arrival") {
            if let map = DeviceXML.parseArrival(xml) {
                parameters = map
                var model = deviceSubject.value
                model.deviceId = map.deviceId
                model.deviceModel = map.deviceModel.isEmpty ? model.deviceModel : map.deviceModel
                model.minGainDb = map.minGainDb
                model.maxGainDb = map.maxGainDb
                model.inputs = map.inputs
                model.outputs = map.outputs
                model.sourceNodes = map.sourceNodes
                model.mixerSlots = map.mixerSlots.map {
                    MixerSlotState(sourceParamId: $0.sourceParamId, stereoParamId: $0.stereoParamId)
                }
                model.mixes = map.mixes.map { mix in
                    MixState(
                        id: mix.id,
                        name: mix.name,
                        stereoName: mix.stereoName,
                        stripIDs: mix.strips,
                        strips: mix.strips.map { _ in MixStripState() },
                        meterParamId: mix.meterParamId
                    )
                }
                meterParamIds = map.meterParamIds
                meters = [:]
                meterSubject.send([:])
                deviceSubject.send(model)
                sendXML(DeviceXML.subscribeMessage(deviceId: map.deviceId))
            }
        }
        
        if let set = DeviceXML.parseSetItems(xml) {
            applySetItems(set.items)
            if stateSubject.value == .awaitingApproval {
                stateSubject.send(.connected)
            }
        }
    }
    
    private func applySetItems(_ items: [(id: String, value: String)]) {
        var metersChanged = false
        var mixerItems: [(id: String, value: String)] = []
        let now = Date()
        for item in items {
            if let until = suppressInboundUntil[item.id], now < until {
                continue
            }
            if meterParamIds.contains(item.id), let db = Double(item.value) {
                let quantized = (db * 2).rounded() / 2
                if meters[item.id] != quantized {
                    meters[item.id] = quantized
                    metersChanged = true
                }
                continue
            }
            mixerItems.append(item)
        }
        if metersChanged {
            scheduleMeterFlush()
        }
        guard !mixerItems.isEmpty else { return }
        var model = deviceSubject.value
        for item in mixerItems {
            apply(item, to: &model)
        }
        if model != deviceSubject.value {
            deviceSubject.send(model)
        }
    }

    private func scheduleMeterFlush() {
        guard meterUpdatesEnabled, meterFlushWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.meterFlushWork = nil
            if self.meterUpdatesEnabled {
                self.meterSubject.send(self.meters)
            }
        }
        meterFlushWork = work
        queue.asyncAfter(deadline: .now() + 0.125, execute: work)
    }
    
    private func apply(_ item: (id: String, value: String), to model: inout Scarlett18i20Gen2Model) {
        if item.id == parameters.hardwareGainId, let db = Double(item.value) {
            model.monitorDb = db
            return
        }
        if item.id == parameters.hardwareMuteId {
            model.monitorMute = item.value == "true" || item.value == "1"
            return
        }
        applyChannelItem(item, to: &model.outputs)
        applyChannelItem(item, to: &model.inputs)
        applyMixerItem(item, to: &model)
        applySourceNickname(item, to: &model)
    }

    private func applyMixerItem(_ item: (id: String, value: String), to model: inout Scarlett18i20Gen2Model) {
        for i in model.mixerSlots.indices {
            if model.mixerSlots[i].sourceParamId == item.id {
                model.mixerSlots[i].sourceNodeId = item.value
            } else if model.mixerSlots[i].stereoParamId == item.id {
                model.mixerSlots[i].stereo = item.value == "true" || item.value == "1"
            }
        }
        for i in model.outputs.indices {
            if model.outputs[i].sourceParamId == item.id {
                model.outputs[i].assignedMixId = item.value
            }
        }
        for i in model.mixes.indices {
            for j in model.mixes[i].stripIDs.indices {
                let ids = model.mixes[i].stripIDs[j]
                if ids.gainId == item.id, let db = Double(item.value) {
                    model.mixes[i].strips[j].gainDb = db
                } else if ids.panId == item.id, let pan = Double(item.value) {
                    model.mixes[i].strips[j].pan = pan
                } else if ids.muteId == item.id {
                    model.mixes[i].strips[j].muted = item.value == "true" || item.value == "1"
                } else if ids.soloId == item.id {
                    model.mixes[i].strips[j].solo = item.value == "true" || item.value == "1"
                }
            }
        }
    }

    private func applySourceNickname(_ item: (id: String, value: String), to model: inout Scarlett18i20Gen2Model) {
        for i in model.sourceNodes.indices where model.sourceNodes[i].nicknameId == item.id {
            model.sourceNodes[i].nickname = item.value
        }
    }
    
    private func applyChannelItem(_ item: (id: String, value: String), to channels: inout [DeviceChannel]) {
        for i in channels.indices {
            if channels[i].gainId == item.id, let db = Double(item.value) {
                channels[i].gainDb = db
            } else if channels[i].muteId == item.id {
                channels[i].muted = item.value == "true" || item.value == "1"
            } else if channels[i].availableId == item.id {
                channels[i].available = item.value == "true" || item.value == "1"
            } else if channels[i].stereoId == item.id {
                channels[i].stereoLinked = item.value == "true" || item.value == "1"
            } else if channels[i].nicknameId == item.id {
                channels[i].nickname = item.value
            }
        }
    }
    
    private func sendClientHello() {
        let name = xmlEscape(clientName)
        let key = xmlEscape(clientKey)
        sendXML("<client-details hostname=\"\(name)\" client-key=\"\(key)\"/>")
    }
    
    private func startKeepAlive() {
        stopKeepAlive()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            self?.sendXML("<keep-alive/>")
        }
        timer.resume()
        keepAliveTimer = timer
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
    }
    
    private func sendXML(_ xml: String) {
        guard let conn = connection else { return }
        conn.send(content: framing.encode(xml: xml), completion: .contentProcessed { _ in })
    }
    
    private func tearDown(state: ConnectionState) {
        stopKeepAlive()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        inboundBuffer.removeAll()
        meterFlushWork?.cancel()
        meterFlushWork = nil
        meters = [:]
        meterParamIds = []
        meterSubject.send([:])
        stateSubject.send(state)
    }
    
    private func scheduleReconnect() {
        guard autoReconnect, !userDisconnected, let server = lastServer else { return }
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.userDisconnected else { return }
            self.connectOnQueue(to: server)
        }
        reconnectWorkItem = item
        queue.asyncAfter(deadline: .now() + 2.0, execute: item)
    }
    
    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    private static func formatDb(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }
}
