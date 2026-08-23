import Testing
@testable import MidiKit

struct MidiTargetTests {
    @Test func roundTripsMonitorAndStripIds() {
        #expect(MidiTarget.parse("monitor") == .monitorGain)
        #expect(MidiTarget.parse("monitorL") == .monitorGain)
        #expect(MidiTarget.parse("mute") == .monitorMute)
        #expect(MidiTarget.mixGain(mixId: "54", slot: 2).id == "strip:54:2:gain")
        #expect(MidiTarget.parse("strip:54:2:gain") == .mixGain(mixId: "54", slot: 2))
        #expect(MidiTarget.parse("output:812:mute") == .outputMute(id: "812"))
        #expect(MidiTarget.parse("master:812:mute") == .outputMute(id: "812"))
        #expect(MidiTarget.parse("nope") == nil)
    }

    @Test func outputTargetsPreferHardwareMonitor() {
        let monitors = MonitorKind(id: "1", isMonitor: true)
        let phones = MonitorKind(id: "880", isMonitor: false)
        #expect(MidiTarget.masterGain(for: monitors) == .monitorGain)
        #expect(MidiTarget.masterMute(for: monitors) == .monitorMute)
        #expect(MidiTarget.masterGain(for: phones) == .outputGain(id: "880"))
        #expect(MidiTarget.masterMute(for: phones) == .outputMute(id: "880"))
    }

    @Test func parseAcceptsLegacyAndStripForms() {
        #expect(MidiTarget.parse("monitorR") == .monitorGain)
        #expect(MidiTarget.parse("output:812:gain") == .outputGain(id: "812"))
        #expect(MidiTarget.parse("master:812:gain") == .outputGain(id: "812"))
        #expect(MidiTarget.parse("strip:54:2:mute") == .mixMute(mixId: "54", slot: 2))
        #expect(MidiTarget.parse("strip:54:2:solo") == .mixSolo(mixId: "54", slot: 2))
        #expect(MidiTarget.parse("strip:54:x:gain") == nil)
        #expect(MidiTarget.parse("strip:54:2:pan") == nil)
        #expect(MidiTarget.parse("output:812:solo") == nil)
        #expect(MidiTarget.parse("") == nil)
    }

    @Test func idsRoundTripThroughParse() {
        let targets: [MidiTarget] = [
            .monitorGain,
            .monitorMute,
            .outputGain(id: "812"),
            .outputMute(id: "812"),
            .mixGain(mixId: "54", slot: 0),
            .mixMute(mixId: "54", slot: 3),
            .mixSolo(mixId: "202", slot: 16)
        ]
        for target in targets {
            #expect(MidiTarget.parse(target.id) == target)
        }
    }

    @Test func compactBindingDescriptionFormatsTypes() {
        let cc = MidiBinding(portUID: 1, channel: 0, type: .cc, number: 7)
        let note = MidiBinding(portUID: 1, channel: 2, type: .noteOn, number: 60)
        let off = MidiBinding(portUID: 1, channel: 2, type: .noteOff, number: 60)
        let bend = MidiBinding(portUID: 1, channel: 0, type: .pitchBend, number: 0)
        #expect(MidiMappingItem(id: "monitor", controlName: "Level", binding: cc).compactBindingDescription == "CC 7 · Ch 1")
        #expect(MidiMappingItem(id: "mute", controlName: "Mute", binding: note).compactBindingDescription == "Note On 60 · Ch 3")
        #expect(MidiMappingItem(id: "mute", controlName: "Mute", binding: off).compactBindingDescription == "Note Off 60 · Ch 3")
        #expect(MidiMappingItem(id: "monitor", controlName: "Level", binding: bend).compactBindingDescription == "Pitch Bend · Ch 1")
        #expect(MidiMappingItem(id: "monitor", controlName: "Level").compactBindingDescription == "Unmapped")
    }
}
