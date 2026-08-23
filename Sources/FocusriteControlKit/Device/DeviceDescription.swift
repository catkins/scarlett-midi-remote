import Foundation

public enum ChannelRole: String, Codable, Equatable {
    case input
    case output
}

public struct DeviceChannel: Identifiable, Equatable {
    public var id: String
    public var role: ChannelRole
    public var kind: String
    public var factoryName: String
    public var stereoName: String
    public var nickname: String
    public var available: Bool
    public var stereoLinked: Bool
    public var muted: Bool
    public var gainDb: Double
    public var isHeadphone: Bool
    public var nicknameId: String?
    public var availableId: String?
    public var stereoId: String?
    public var muteId: String?
    public var gainId: String?
    /// Hardware element id used as a mixer source value (e.g. "795").
    public var elementId: String?
    /// Output `source` parameter id whose value is the assigned mix id.
    public var sourceParamId: String?
    public var assignedMixId: String
    public var meterParamId: String?

    public var displayName: String {
        mixerDisplayName(nickname: nickname, factoryName: factoryName)
    }

    public init(id: String,
                role: ChannelRole,
                kind: String,
                factoryName: String,
                stereoName: String = "",
                nickname: String = "",
                available: Bool = true,
                stereoLinked: Bool = false,
                muted: Bool = false,
                gainDb: Double = 0,
                isHeadphone: Bool = false,
                nicknameId: String? = nil,
                availableId: String? = nil,
                stereoId: String? = nil,
                muteId: String? = nil,
                gainId: String? = nil,
                elementId: String? = nil,
                sourceParamId: String? = nil,
                assignedMixId: String = "",
                meterParamId: String? = nil) {
        self.id = id
        self.role = role
        self.kind = kind
        self.factoryName = factoryName
        self.stereoName = stereoName
        self.nickname = nickname
        self.available = available
        self.stereoLinked = stereoLinked
        self.muted = muted
        self.gainDb = gainDb
        self.isHeadphone = isHeadphone
        self.nicknameId = nicknameId
        self.availableId = availableId
        self.stereoId = stereoId
        self.muteId = muteId
        self.gainId = gainId
        self.elementId = elementId
        self.sourceParamId = sourceParamId
        self.assignedMixId = assignedMixId
        self.meterParamId = meterParamId
    }
}

public struct DeviceParameterMap: Equatable {
    public var deviceId: String = ""
    public var deviceModel: String = ""
    public var hardwareGainId: String?
    public var hardwareMuteId: String?
    public var hardwareDimId: String?
    public var minGainDb: Double = -80
    public var maxGainDb: Double = 10
    public var inputs: [DeviceChannel] = []
    public var outputs: [DeviceChannel] = []
    public var mixerSlots: [MixerSlotDescriptor] = []
    public var mixes: [MixDescriptor] = []
    public var sourceNodes: [MixSourceNode] = []

    public var meterParamIds: Set<String> {
        var ids = Set<String>()
        for node in sourceNodes {
            if let id = node.meterParamId, !id.isEmpty { ids.insert(id) }
        }
        for channel in outputs {
            if let id = channel.meterParamId, !id.isEmpty { ids.insert(id) }
        }
        for mix in mixes where !mix.meterParamId.isEmpty {
            ids.insert(mix.meterParamId)
        }
        return ids
    }

    public var gainRange: ClosedRange<Double> {
        min(minGainDb, maxGainDb)...max(minGainDb, maxGainDb)
    }

    public init() {}
}

public enum DeviceXML {
    public static func parseArrival(_ xml: String) -> DeviceParameterMap? {
        DeviceArrivalParser.parse(xml)
    }

    public static func parseClientId(_ xml: String) -> String? {
        attribute(named: "id", in: xml, element: "client-details")
    }

    public static func parseApprovalAuthorised(_ xml: String) -> Bool? {
        guard xml.contains("<approval") else { return nil }
        if let value = attribute(named: "authorised", in: xml, element: "approval")
            ?? attribute(named: "authorized", in: xml, element: "approval") {
            return isTruthy(value)
        }
        return nil
    }

    public static func parseSetItems(_ xml: String) -> (deviceId: String, items: [(id: String, value: String)])? {
        guard xml.contains("<set") else { return nil }
        let deviceId = attribute(named: "devid", in: xml, element: "set") ?? ""
        var items: [(String, String)] = []
        let ns = xml as NSString
        for match in setItemRegex.matches(in: xml, range: NSRange(location: 0, length: ns.length)) {
            items.append((ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2))))
        }
        return (deviceId, items)
    }

    private static let setItemRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"<item\s+id="([^"]+)"\s+value="([^"]*)"\s*/>"#)
    }()

    public static func setMessage(deviceId: String, items: [(id: String, value: String)]) -> String {
        let body = items.map { "<item id=\"\($0.id)\" value=\"\($0.value)\"/>" }.joined()
        return "<set devid=\"\(deviceId)\">\(body)</set>"
    }

    public static func subscribeMessage(deviceId: String) -> String {
        "<device-subscribe devid=\"\(deviceId)\" subscribe=\"true\"/>"
    }

    public static func isTruthy(_ value: String) -> Bool {
        value == "true" || value == "1"
    }

    static func attribute(named name: String, in xml: String, element: String) -> String? {
        let pattern = "<\(element)\\b[^>]*\\b\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              let range = Range(match.range(at: 1), in: xml) else { return nil }
        return String(xml[range])
    }
}

private final class DeviceArrivalParser: NSObject, XMLParserDelegate {
    private var map = DeviceParameterMap()
    private var path: [String] = []
    private var insideMonitoringHardware = false

    private var pendingKind = ""
    private var pendingName = ""
    private var pendingStereoName = ""
    private var pendingHeadphone = false
    private var pendingElementId: String?
    private var pendingNicknameId: String?
    private var pendingAvailableId: String?
    private var pendingStereoId: String?
    private var pendingMuteId: String?
    private var pendingGainId: String?
    private var pendingSourceParamId: String?
    private var pendingMeterId: String?
    private var pendingMixMeterId: String?

    private var pendingMixerSourceParamId: String?
    private var pendingMixerStereoParamId: String?

    private var pendingMixId = ""
    private var pendingMixName = ""
    private var pendingMixStereoName = ""
    private var pendingMixStrips: [MixStripIDs] = []
    private var pendingMixGainId: String?
    private var pendingMixPanId: String?
    private var pendingMixMuteId: String?
    private var pendingMixSoloId: String?

    static func parse(_ xml: String) -> DeviceParameterMap? {
        let parser = DeviceArrivalParser()
        guard let data = xml.data(using: .utf8) else { return nil }
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else { return nil }
        guard !parser.map.deviceId.isEmpty else { return nil }
        return parser.map
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        path.append(elementName)
        switch elementName {
        case "device":
            map.deviceId = attributes["id"] ?? map.deviceId
            map.deviceModel = attributes["model"] ?? map.deviceModel
        case "analogue", "adat", "spdif-rca", "playback":
            resetPendingChannel()
            pendingKind = elementName
            pendingName = attributes["name"] ?? ""
            pendingStereoName = attributes["stereo-name"] ?? ""
            pendingHeadphone = (attributes["headphone"] ?? "0") != "0"
            pendingElementId = attributes["id"]
        case "hardware-controls":
            if path.contains("monitoring") {
                insideMonitoringHardware = true
                if let min = attributes["min-gain"].flatMap(Double.init) { map.minGainDb = min }
                if let max = attributes["max-gain"].flatMap(Double.init) { map.maxGainDb = max }
            }
        case "mix":
            if path.contains("mixes") {
                pendingMixId = attributes["id"] ?? ""
                pendingMixName = attributes["name"] ?? ""
                pendingMixStereoName = attributes["stereo-name"] ?? ""
                pendingMixStrips = []
                pendingMixMeterId = nil
            }
        case "meter":
            if let id = attributes["id"] {
                if path.contains("mixes"), path.contains("mix"), !path.contains("input") {
                    pendingMixMeterId = id
                } else {
                    pendingMeterId = id
                }
            }
        case "input":
            if isMixerSlotPath {
                pendingMixerSourceParamId = nil
                pendingMixerStereoParamId = nil
            } else if isMixStripPath {
                pendingMixGainId = nil
                pendingMixPanId = nil
                pendingMixMuteId = nil
                pendingMixSoloId = nil
            }
        case "source":
            if isMixerSlotPath {
                pendingMixerSourceParamId = attributes["id"]
            } else if path.contains("outputs") {
                pendingSourceParamId = attributes["id"]
            }
        case "gain":
            if let id = attributes["id"] {
                if insideMonitoringHardware {
                    map.hardwareGainId = id
                } else if isMixStripPath {
                    pendingMixGainId = id
                } else {
                    pendingGainId = id
                }
            }
        case "pan":
            if isMixStripPath { pendingMixPanId = attributes["id"] }
        case "solo":
            if isMixStripPath { pendingMixSoloId = attributes["id"] }
        case "mute":
            if let id = attributes["id"] {
                if insideMonitoringHardware {
                    map.hardwareMuteId = id
                } else if isMixStripPath {
                    pendingMixMuteId = id
                } else {
                    pendingMuteId = id
                }
            }
        case "dim":
            if insideMonitoringHardware, let id = attributes["id"] {
                map.hardwareDimId = id
            }
        case "nickname":
            pendingNicknameId = attributes["id"]
        case "available":
            pendingAvailableId = attributes["id"]
        case "stereo":
            if isMixerSlotPath {
                pendingMixerStereoParamId = attributes["id"]
            } else {
                pendingStereoId = attributes["id"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "input" {
            if isMixerSlotPath {
                finishMixerSlot()
            } else if isMixStripPath {
                finishMixStrip()
            }
        }
        if elementName == "mix", path.contains("mixes") {
            finishMix()
        }
        if elementName == "analogue" || elementName == "adat" || elementName == "spdif-rca" || elementName == "playback" {
            finishPendingChannel()
        }
        if elementName == "hardware-controls", insideMonitoringHardware, path.filter({ $0 == "hardware-controls" }).count == 1 {
            insideMonitoringHardware = false
        }
        if !path.isEmpty { path.removeLast() }
    }

    private var isMixerSlotPath: Bool {
        path.contains("mixer") && path.contains("inputs") && path.contains("input") && !path.contains("mixes")
    }

    private var isMixStripPath: Bool {
        path.contains("mixes") && path.contains("mix") && path.contains("input")
    }

    private func resetPendingChannel() {
        pendingKind = ""
        pendingName = ""
        pendingStereoName = ""
        pendingHeadphone = false
        pendingElementId = nil
        pendingNicknameId = nil
        pendingAvailableId = nil
        pendingStereoId = nil
        pendingMuteId = nil
        pendingGainId = nil
        pendingSourceParamId = nil
        pendingMeterId = nil
    }

    private func finishMixerSlot() {
        guard let sourceId = pendingMixerSourceParamId, let stereoId = pendingMixerStereoParamId else { return }
        map.mixerSlots.append(MixerSlotDescriptor(sourceParamId: sourceId, stereoParamId: stereoId))
        pendingMixerSourceParamId = nil
        pendingMixerStereoParamId = nil
    }

    private func finishMixStrip() {
        guard let gainId = pendingMixGainId else { return }
        pendingMixStrips.append(
            MixStripIDs(
                gainId: gainId,
                panId: pendingMixPanId ?? "",
                muteId: pendingMixMuteId ?? "",
                soloId: pendingMixSoloId ?? ""
            )
        )
        pendingMixGainId = nil
        pendingMixPanId = nil
        pendingMixMuteId = nil
        pendingMixSoloId = nil
    }

    private func finishMix() {
        guard !pendingMixId.isEmpty else { return }
        map.mixes.append(
            MixDescriptor(
                id: pendingMixId,
                name: pendingMixName,
                stereoName: pendingMixStereoName,
                strips: pendingMixStrips,
                meterParamId: pendingMixMeterId ?? ""
            )
        )
        pendingMixId = ""
        pendingMixName = ""
        pendingMixStereoName = ""
        pendingMixStrips = []
        pendingMixMeterId = nil
    }

    private func finishPendingChannel() {
        if let elementId = pendingElementId, !pendingName.isEmpty, !path.contains("outputs") {
            map.sourceNodes.append(
                MixSourceNode(
                    id: elementId,
                    kind: pendingKind,
                    factoryName: pendingName,
                    stereoName: pendingStereoName,
                    nicknameId: pendingNicknameId,
                    meterParamId: pendingMeterId
                )
            )
        }

        guard !pendingName.isEmpty else { return }
        let isOutput = path.contains("outputs") || pendingName.lowercased().contains("output")
        if pendingKind == "playback", !isOutput {
            resetPendingChannel()
            return
        }
        let channel = DeviceChannel(
            id: "\(isOutput ? "out" : "in")-\(pendingKind)-\(pendingName)",
            role: isOutput ? .output : .input,
            kind: pendingKind,
            factoryName: pendingName,
            stereoName: pendingStereoName,
            isHeadphone: pendingHeadphone,
            nicknameId: pendingNicknameId,
            availableId: pendingAvailableId,
            stereoId: pendingStereoId,
            muteId: pendingMuteId,
            gainId: pendingGainId,
            elementId: pendingElementId,
            sourceParamId: pendingSourceParamId,
            meterParamId: pendingMeterId
        )
        if isOutput {
            map.outputs.append(channel)
        } else {
            map.inputs.append(channel)
        }
        resetPendingChannel()
    }
}
