import Foundation
import CoreMIDI

public protocol MidiManagerProtocol {
    var onLearnedMessage: ((MidiMessage) -> Void)? { get set }
    func availableInputs() -> [MidiInputInfo]
    func selectInput(uid: Int32)
    // Back-compat helpers (optional)
    func availableInputNames() -> [String]
    func selectInput(named name: String)
    func setLearningEnabled(_ enabled: Bool)
}

public struct MidiInputInfo: Codable, Equatable, Hashable {
    public let uid: Int32
    public let name: String
    
    public init(uid: Int32, name: String) {
        self.uid = uid
        self.name = name
    }
}

public struct MidiMessage: Codable, Equatable {
    public enum Kind: String, Codable { case controlChange, noteOn, noteOff, pitchBend, unknown }
    public var kind: Kind
    public var channel: UInt8
    public var data1: UInt8
    public var data2: UInt8
    
    public init(kind: Kind, channel: UInt8, data1: UInt8, data2: UInt8) {
        self.kind = kind
        self.channel = channel
        self.data1 = data1
        self.data2 = data2
    }
    
    public var shortDescription: String {
        switch kind {
        case .controlChange: return "CC ch\(channel+1) #\(data1) = \(data2)"
        case .noteOn: return "NoteOn ch\(channel+1) \(data1) vel \(data2)"
        case .noteOff: return "NoteOff ch\(channel+1) \(data1)"
        case .pitchBend: return "PitchBend ch\(channel+1)"
        case .unknown: return "MIDI 0x\(String(format: "%02X", data1)) 0x\(String(format: "%02X", data2))"
        }
    }
}

public final class MidiManager: NSObject, MidiManagerProtocol {
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var selectedSource: MIDIEndpointRef?
    private var selectedSourceUID: Int32?
    private var learningEnabled = false
    private let settingsStore: SettingsStoring
    
    public var onLearnedMessage: ((MidiMessage) -> Void)?
    
    public init(settingsStore: SettingsStoring) {
        self.settingsStore = settingsStore
        super.init()
        MIDIClientCreate("ScarlettMidiControl" as CFString, nil, nil, &client)
        MIDIInputPortCreate(client, "Input" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
    }
    
    deinit {
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }
    
    public func availableInputs() -> [MidiInputInfo] {
        let count = MIDIGetNumberOfSources()
        var inputs: [MidiInputInfo] = []
        for i in 0..<count {
            let src = MIDIGetSource(i)
            inputs.append(MidiInputInfo(uid: endpointUID(src), name: endpointName(src)))
        }
        return inputs
    }
    
    public func availableInputNames() -> [String] {
        availableInputs().map { $0.name }
    }
    
    public func selectInput(uid: Int32) {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            if endpointUID(src) == uid {
                if let selected = selectedSource {
                    MIDIPortDisconnectSource(inputPort, selected)
                }
                MIDIPortConnectSource(inputPort, src, nil)
                selectedSource = src
                selectedSourceUID = uid
                settingsStore.selectedMidiInputUID = uid
                break
            }
        }
    }
    
    public func selectInput(named name: String) {
        if let match = availableInputs().first(where: { $0.name == name }) {
            selectInput(uid: match.uid)
        }
    }
    
    public func setLearningEnabled(_ enabled: Bool) {
        learningEnabled = enabled
    }
    
    private func endpointName(_ endpoint: MIDIObjectRef) -> String {
        var param: Unmanaged<CFString>?
        var name: String = "Unknown"
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &param)
        if status == noErr, let take = param?.takeRetainedValue() {
            name = take as String
        }
        return name
    }
    
    private func endpointUID(_ endpoint: MIDIObjectRef) -> Int32 {
        var value: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &value)
        if status == noErr {
            return value
        }
        return -1
    }
    
    private let midiReadProc: MIDIReadProc = { packetList, srcConnRefCon, _ in
        guard let srcConnRefCon else { return }
        let mySelf = Unmanaged<MidiManager>.fromOpaque(srcConnRefCon).takeUnretainedValue()
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let bytes = Mirror(reflecting: packet.data).children
                .compactMap { $0.value as? UInt8 }
            if bytes.count >= 3 {
                let status = bytes[0]
                let data1 = bytes[1]
                let data2 = bytes[2]
                let channel = status & 0x0F
                let type = status & 0xF0
                var message = MidiMessage(kind: .unknown, channel: channel, data1: data1, data2: data2)
                switch type {
                case 0xB0: message.kind = .controlChange
                case 0x90: message.kind = .noteOn
                case 0x80: message.kind = .noteOff
                case 0xE0: message.kind = .pitchBend
                default: break
                }
                if mySelf.learningEnabled {
                    mySelf.onLearnedMessage?(message)
                }
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}

