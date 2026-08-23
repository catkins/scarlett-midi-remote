import Foundation

public struct MidiBinding: Identifiable, Codable, Equatable, Sendable {
    public enum MessageType: String, Codable, Sendable { case cc, noteOn, noteOff, pitchBend }
    public var id: String { "\(portUID)-\(channel)-\(type)-\(number)" }
    public let portUID: Int32
    public let channel: UInt8
    public let type: MessageType
    public let number: UInt8

    public init(portUID: Int32, channel: UInt8, type: MessageType, number: UInt8) {
        self.portUID = portUID
        self.channel = channel
        self.type = type
        self.number = number
    }
}

public struct MidiMappingItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var controlName: String
    public var binding: MidiBinding?

    public init(id: String, controlName: String, binding: MidiBinding? = nil) {
        self.id = id
        self.controlName = controlName
        self.binding = binding
    }

    public var compactBindingDescription: String {
        guard let binding else { return "Unmapped" }
        switch binding.type {
        case .cc: return "CC \(binding.number) · Ch \(binding.channel + 1)"
        case .noteOn: return "Note On \(binding.number) · Ch \(binding.channel + 1)"
        case .noteOff: return "Note Off \(binding.number) · Ch \(binding.channel + 1)"
        case .pitchBend: return "Pitch Bend · Ch \(binding.channel + 1)"
        }
    }
}
