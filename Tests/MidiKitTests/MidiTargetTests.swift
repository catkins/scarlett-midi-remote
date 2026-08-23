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
        #expect(MidiTarget.masterMute(for: phones) == .outputMute(id: "880"))
    }
}
