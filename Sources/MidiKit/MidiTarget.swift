import Foundation

/// Stable MIDI mapping keys. Legacy `monitor` / `mute` IDs are still accepted.
public enum MidiTarget: Equatable, Sendable {
    case monitorGain
    case monitorMute
    case outputGain(id: String)
    case outputMute(id: String)
    case mixGain(mixId: String, slot: Int)
    case mixMute(mixId: String, slot: Int)
    case mixSolo(mixId: String, slot: Int)

    public var id: String {
        switch self {
        case .monitorGain: return "monitor"
        case .monitorMute: return "mute"
        case .outputGain(let id): return "output:\(id):gain"
        case .outputMute(let id): return "output:\(id):mute"
        case .mixGain(let mixId, let slot): return "strip:\(mixId):\(slot):gain"
        case .mixMute(let mixId, let slot): return "strip:\(mixId):\(slot):mute"
        case .mixSolo(let mixId, let slot): return "strip:\(mixId):\(slot):solo"
        }
    }

    public static func parse(_ raw: String) -> MidiTarget? {
        switch raw {
        case "monitor", "monitorL", "monitorR":
            return .monitorGain
        case "mute":
            return .monitorMute
        default:
            break
        }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 3, parts[0] == "output" || parts[0] == "master" {
            switch parts[2] {
            case "gain": return .outputGain(id: parts[1])
            case "mute": return .outputMute(id: parts[1])
            default: return nil
            }
        }
        if parts.count == 4, parts[0] == "strip", let slot = Int(parts[2]) {
            switch parts[3] {
            case "gain": return .mixGain(mixId: parts[1], slot: slot)
            case "mute": return .mixMute(mixId: parts[1], slot: slot)
            case "solo": return .mixSolo(mixId: parts[1], slot: slot)
            default: return nil
            }
        }
        return nil
    }

    public static func masterGain(for output: MonitorKind) -> MidiTarget {
        output.isMonitor ? .monitorGain : .outputGain(id: output.id)
    }

    public static func masterMute(for output: MonitorKind) -> MidiTarget {
        output.isMonitor ? .monitorMute : .outputMute(id: output.id)
    }
}

public struct MonitorKind: Equatable, Sendable {
    public var id: String
    public var isMonitor: Bool

    public init(id: String, isMonitor: Bool) {
        self.id = id
        self.isMonitor = isMonitor
    }
}
