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
    func connect(to server: DiscoveredServer)
    func disconnect()
    func requestDeviceSnapshot()
    func setMonitorMute(_ enabled: Bool)
}

public final class ControlServerClient: ControlServerClientProtocol {
    private let stateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    public var statePublisher: AnyPublisher<ConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    
    private var connection: NWConnection?
    private var keepAliveTimer: Timer?
    private let framing = ProtocolFraming()
    private var inboundBuffer = Data()
    private var lastServer: DiscoveredServer?
    private var reconnectWorkItem: DispatchWorkItem?
    
    // Configurable settings (bound from app Settings)
    public var clientName: String = "Scarlett MIDI Control"
    public var autoReconnect: Bool = true
    
    public init() {}
    
    public func connect(to server: DiscoveredServer) {
        stateSubject.send(.connecting)
        lastServer = server
        let params = NWParameters.tcp
        let endpoint = NWEndpoint.Host(server.host)
        let port = NWEndpoint.Port(rawValue: server.port) ?? .init(integerLiteral: 49152)
        let conn = NWConnection(host: endpoint, port: port, using: params)
        connection = conn
        conn.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                self?.stateSubject.send(.awaitingApproval) // will transition to connected after approval handshake
                self?.startReceiveLoop()
                self?.sendClientHello()
                self?.startKeepAlive()
            case .failed(let error):
                self?.stateSubject.send(.error(error.localizedDescription))
                self?.scheduleReconnect()
            case .waiting(let error):
                self?.stateSubject.send(.error(error.localizedDescription))
                self?.scheduleReconnect()
            default:
                break
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }
    
    public func disconnect() {
        connection?.cancel()
        connection = nil
        stopKeepAlive()
        stateSubject.send(.disconnected)
    }
    
    public func requestDeviceSnapshot() {
        // TODO: Send the appropriate subscription/snapshot message after handshake is verified
    }
    
    public func setMonitorMute(_ enabled: Bool) {
        // TODO: Encode and send control message to toggle monitor mute
    }
    
    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.inboundBuffer.append(data)
                self.processInbound()
            }
            if isComplete {
                self.disconnect()
                return
            }
            if let error {
                self.stateSubject.send(.error(error.localizedDescription))
                return
            }
            self.startReceiveLoop()
        }
    }
    
    private func processInbound() {
        let frames = framing.tryParseFrames(from: &inboundBuffer)
        for xml in frames {
            // Parse server messages; update state
            // UNVERIFIED: Expect a device description, then approval state, then value updates
            if xml.contains("approval=\"granted\"") {
                stateSubject.send(.connected)
            }
        }
    }
    
    private func sendClientHello() {
        // UNVERIFIED placeholder hello; real implementation must match the classic client fields
        let safeName = clientName.replacingOccurrences(of: "\"", with: "'")
        let hello = "<client-details name=\"\(safeName)\" key=\"swiftui\"/>"
        sendXML(hello)
    }
    
    private func startKeepAlive() {
        stopKeepAlive()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.sendXML("<keep-alive/>")
        }
        RunLoop.current.add(keepAliveTimer!, forMode: .common)
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    private func sendXML(_ xml: String) {
        guard let conn = connection else { return }
        let data = framing.encode(xml: xml)
        conn.send(content: data, completion: .contentProcessed { _ in })
    }
    
    private func scheduleReconnect() {
        guard autoReconnect, let server = lastServer else { return }
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .connected = self.stateSubject.value { return }
            self.connect(to: server)
        }
        reconnectWorkItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0, execute: item)
    }
}

