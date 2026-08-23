import Foundation
import Testing
@testable import FocusriteControlKit

struct MixerLayoutTests {
    @Test func stereoLinkedSlotsCollapseToOneStrip() {
        let sources = [
            MixSourceNode(id: "811", kind: "analogue", factoryName: "Analogue 5", stereoName: "Analogue 5-6", nickname: "Prophet"),
            MixSourceNode(id: "867", kind: "playback", factoryName: "Playback 1", stereoName: "Playback 1-2")
        ]
        let slots = [
            MixerSlotState(sourceParamId: "18", stereoParamId: "19", sourceNodeId: "811", stereo: true),
            MixerSlotState(sourceParamId: "20", stereoParamId: "21", sourceNodeId: "", stereo: false),
            MixerSlotState(sourceParamId: "22", stereoParamId: "23", sourceNodeId: "867", stereo: true),
            MixerSlotState(sourceParamId: "24", stereoParamId: "25", sourceNodeId: "", stereo: false)
        ]
        let mix = MixState(
            id: "54",
            name: "Mix A",
            stereoName: "Mix A",
            stripIDs: (0..<4).map { MixStripIDs(gainId: "g\($0)", panId: "p\($0)", muteId: "m\($0)", soloId: "s\($0)") },
            strips: [
                MixStripState(gainDb: 0),
                MixStripState(gainDb: 0),
                MixStripState(gainDb: -6),
                MixStripState(gainDb: -6)
            ]
        )
        let strips = MixerLayout.visibleStrips(mix: mix, slots: slots, sources: sources)
        #expect(strips.count == 2)
        #expect(strips[0].title == "Prophet")
        #expect(strips[0].stereo == true)
        #expect(strips[0].partnerSlotIndex == 1)
        #expect(strips[1].title == "Playback 1-2" || strips[1].title == "Playback 1")
        #expect(strips[1].stereo == true)
    }

    @Test func monoSlotsKeepSeparateFaders() {
        let sources = [
            MixSourceNode(id: "795", kind: "analogue", factoryName: "Analogue 1", stereoName: "Analogue 1-2", nickname: "Røde NT1"),
            MixSourceNode(id: "799", kind: "analogue", factoryName: "Analogue 2", stereoName: "", nickname: "")
        ]
        let slots = [
            MixerSlotState(sourceParamId: "50", stereoParamId: "51", sourceNodeId: "795", stereo: false),
            MixerSlotState(sourceParamId: "52", stereoParamId: "53", sourceNodeId: "799", stereo: false)
        ]
        let mix = MixState(
            id: "54",
            name: "Mix A",
            stereoName: "Mix A",
            stripIDs: [
                MixStripIDs(gainId: "55", panId: "56", muteId: "57", soloId: "58"),
                MixStripIDs(gainId: "59", panId: "60", muteId: "61", soloId: "62")
            ],
            strips: [MixStripState(gainDb: -3), MixStripState(gainDb: -9)]
        )
        let strips = MixerLayout.visibleStrips(mix: mix, slots: slots, sources: sources)
        #expect(strips.count == 2)
        #expect(strips[0].stereo == false)
        #expect(strips[1].stereo == false)
        #expect(strips[0].title == "Røde NT1")
        #expect(strips[1].title == "Analogue 2")
        #expect(strips[0].partnerSlotIndex == nil)
    }

    @Test func parseArrivalCapturesMixerSlotsAndMixes() {
        let xml = """
        <device-arrival>
          <device id="1" model="Scarlett 18i20 2nd Gen">
            <mixer>
              <inputs>
                <input><source id="18"/><stereo id="19"/></input>
                <input><source id="20"/><stereo id="21"/></input>
              </inputs>
              <mixes>
                <mix id="54" name="Mix A" stereo-name="Mix A">
                  <meter id="127"/>
                  <input><gain id="55"/><pan id="56"/><mute id="57"/><solo id="58"/></input>
                  <input><gain id="59"/><pan id="60"/><mute id="61"/><solo id="62"/></input>
                </mix>
              </mixes>
            </mixer>
            <inputs>
              <analogue id="795" name="Analogue 1" stereo-name="Analogue 1-2">
                <nickname id="796"/><meter id="798"/>
              </analogue>
              <playback id="867" name="Playback 1" stereo-name="Playback 1-2">
                <nickname id="868"/>
              </playback>
            </inputs>
            <outputs>
              <analogue name="Monitor Output 1" stereo-name="Monitor Outputs 1-2">
                <source id="952"/><mute id="951"/><gain id="956"/><stereo id="953"/><meter id="948"/>
              </analogue>
            </outputs>
            <monitoring>
              <hardware-controls min-gain="-128" max-gain="0">
                <gain id="1127"/><mute id="1129"/>
              </hardware-controls>
            </monitoring>
          </device>
        </device-arrival>
        """
        let map = DeviceXML.parseArrival(xml)
        #expect(map?.deviceId == "1")
        #expect(map?.mixerSlots.count == 2)
        #expect(map?.mixerSlots.first?.sourceParamId == "18")
        #expect(map?.mixes.count == 1)
        #expect(map?.mixes.first?.id == "54")
        #expect(map?.mixes.first?.strips.count == 2)
        #expect(map?.sourceNodes.contains(where: { $0.id == "795" }) == true)
        #expect(map?.sourceNodes.contains(where: { $0.id == "867" && $0.kind == "playback" }) == true)
        #expect(map?.outputs.first?.sourceParamId == "952")
        #expect(map?.sourceNodes.first(where: { $0.id == "795" })?.meterParamId == "798")
        #expect(map?.mixes.first?.meterParamId == "127")
        #expect(map?.outputs.first?.meterParamId == "948")
        #expect(map?.meterParamIds.contains("798") == true)
        #expect(map?.hardwareGainId == "1127")
        #expect(map?.hardwareMuteId == "1129")
        #expect(map?.inputs.contains(where: { $0.kind == "playback" }) == false)
        #expect(map?.sourceNodes.contains(where: { $0.kind == "playback" }) == true)
    }

    @Test func meterFillClampsSilenceAndPeaks() {
        #expect(MixerLayout.meterFill(db: -128) == 0)
        #expect(MixerLayout.meterFill(db: -60) == 0)
        #expect(MixerLayout.meterFill(db: -30) == 0.5)
        #expect(MixerLayout.meterFill(db: 0) == 1)
        #expect(MixerLayout.meterFill(db: 6) == 1)
        #expect(MixerLayout.meterFill(db: -40, floor: -40, ceiling: -20) == 0)
        #expect(MixerLayout.meterFill(db: -20, floor: -40, ceiling: -20) == 1)
    }

    @Test func quantizeMeterSnapsToHalfDb() {
        #expect(MixerLayout.quantizeMeter(-27) == -27)
        #expect(MixerLayout.quantizeMeter(-27.2) == -27)
        #expect(MixerLayout.quantizeMeter(-27.3) == -27.5)
    }

    @Test func applyMeterItemIsFastPathOnlyForKnownNumericMeters() {
        var meters: [String: Double] = [:]
        let ids: Set<String> = ["798", "948"]

        #expect(MixerLayout.applyMeterItem(id: "55", value: "-3", meterIds: ids, meters: &meters) == .ignored)
        #expect(meters.isEmpty)

        #expect(MixerLayout.applyMeterItem(id: "798", value: "oops", meterIds: ids, meters: &meters) == .ignored)
        #expect(meters.isEmpty)

        #expect(MixerLayout.applyMeterItem(id: "798", value: "-27.2", meterIds: ids, meters: &meters) == .updated)
        #expect(meters["798"] == -27)

        #expect(MixerLayout.applyMeterItem(id: "798", value: "-27.1", meterIds: ids, meters: &meters) == .unchanged)
        #expect(meters["798"] == -27)

        #expect(MixerLayout.applyMeterItem(id: "798", value: "-12.3", meterIds: ids, meters: &meters) == .updated)
        #expect(meters["798"] == -12.5)
    }

    @Test func writeSlotIndicesIncludesStereoPartnerWhenInRange() {
        #expect(MixerLayout.writeSlotIndices(slotIndex: 0, stereo: false, stripCount: 18) == [0])
        #expect(MixerLayout.writeSlotIndices(slotIndex: 0, stereo: true, stripCount: 18) == [0, 1])
        #expect(MixerLayout.writeSlotIndices(slotIndex: 17, stereo: true, stripCount: 18) == [17])
    }

    @Test func writeTargetsCoverStereoSlotsAndPartnerMix() {
        let left = MixState(
            id: "54",
            name: "Mix A",
            stereoName: "Mix A",
            stripIDs: (0..<2).map { MixStripIDs(gainId: "gL\($0)", panId: "", muteId: "", soloId: "") },
            strips: [MixStripState(), MixStripState()]
        )
        let right = MixState(
            id: "55",
            name: "Mix A",
            stereoName: "",
            stripIDs: (0..<2).map { MixStripIDs(gainId: "gR\($0)", panId: "", muteId: "", soloId: "") },
            strips: [MixStripState(), MixStripState()]
        )
        let slots = [
            MixerSlotState(sourceParamId: "18", stereoParamId: "19", sourceNodeId: "795", stereo: true),
            MixerSlotState(sourceParamId: "20", stereoParamId: "21", sourceNodeId: "", stereo: false)
        ]

        let stereo = MixerLayout.writeTargets(mixId: "54", slotIndex: 0, mixes: [left, right], slots: slots)
        #expect(stereo == [
            MixWriteTarget(mixIndex: 0, slotIndex: 0),
            MixWriteTarget(mixIndex: 0, slotIndex: 1),
            MixWriteTarget(mixIndex: 1, slotIndex: 0),
            MixWriteTarget(mixIndex: 1, slotIndex: 1)
        ])

        var monoSlots = slots
        monoSlots[0].stereo = false
        let mono = MixerLayout.writeTargets(mixId: "55", slotIndex: 0, mixes: [left, right], slots: monoSlots)
        #expect(mono == [
            MixWriteTarget(mixIndex: 0, slotIndex: 0),
            MixWriteTarget(mixIndex: 1, slotIndex: 0)
        ])

        #expect(MixerLayout.writeTargets(mixId: "missing", slotIndex: 0, mixes: [left], slots: slots).isEmpty)
    }

    @Test func leftAndPartnerMixResolveStereoPair() {
        let left = MixState(id: "54", name: "Mix A", stereoName: "Mix A", stripIDs: [], strips: [])
        let right = MixState(id: "55", name: "Mix A", stereoName: "", stripIDs: [], strips: [])
        #expect(MixerLayout.leftMix(forMixId: "54", in: [left, right])?.id == "54")
        #expect(MixerLayout.leftMix(forMixId: "55", in: [left, right])?.id == "54")
        #expect(MixerLayout.partnerMix(for: left, in: [left, right])?.id == "55")
        #expect(MixerLayout.leftMix(forMixId: "99", in: [left, right]) == nil)
    }

    @Test func outputPairsCollapseStereoAndDetectMonitor() {
        let outputs = [
            DeviceChannel(
                id: "out-mon-l",
                role: .output,
                kind: "analogue",
                factoryName: "Monitor Output 1",
                stereoName: "Monitor Outputs 1-2",
                stereoLinked: true,
                meterParamId: "948"
            ),
            DeviceChannel(
                id: "out-mon-r",
                role: .output,
                kind: "analogue",
                factoryName: "Monitor Output 2",
                stereoLinked: true
            ),
            DeviceChannel(
                id: "out-hp",
                role: .output,
                kind: "analogue",
                factoryName: "Headphones 1",
                nickname: "Cans"
            )
        ]
        let pairs = MixerLayout.outputPairs(from: outputs)
        #expect(pairs.count == 2)
        #expect(pairs[0].title == "Monitor Outputs 1-2")
        #expect(pairs[0].isMonitor)
        #expect(pairs[0].rightId == "out-mon-r")
        #expect(pairs[0].meterParamId == "948")
        #expect(pairs[1].title == "Cans")
        #expect(pairs[1].isMonitor == false)
        #expect(pairs[1].rightId == nil)
    }

    @Test func visibleStripsSkipEmptySlotsAndUseStereoName() {
        let sources = [
            MixSourceNode(id: "795", kind: "analogue", factoryName: "Analogue 1", stereoName: "Analogue 1-2", meterParamId: "798"),
            MixSourceNode(id: "799", kind: "analogue", factoryName: "Analogue 2", stereoName: "", meterParamId: "800")
        ]
        let slots = [
            MixerSlotState(sourceParamId: "18", stereoParamId: "19", sourceNodeId: "", stereo: false),
            MixerSlotState(sourceParamId: "20", stereoParamId: "21", sourceNodeId: "795", stereo: true),
            MixerSlotState(sourceParamId: "22", stereoParamId: "23", sourceNodeId: "", stereo: false)
        ]
        let mix = MixState(
            id: "54",
            name: "Mix A",
            stereoName: "Mix A",
            stripIDs: [],
            strips: []
        )
        let strips = MixerLayout.visibleStrips(mix: mix, slots: slots, sources: sources)
        #expect(strips.count == 1)
        #expect(strips[0].title == "Analogue 1-2")
        #expect(strips[0].slotIndex == 1)
        #expect(strips[0].partnerSlotIndex == 2)
        #expect(strips[0].meterParamId == "798")
        #expect(strips[0].partnerMeterParamId == "800")
        #expect(strips[0].meterIds == ["798", "800"])
    }

    @Test func visibleStripsFallbackTitleWhenSourceMissing() {
        let slots = [
            MixerSlotState(sourceParamId: "18", stereoParamId: "19", sourceNodeId: "missing", stereo: false)
        ]
        let mix = MixState(id: "54", name: "Mix A", stereoName: "Mix A", stripIDs: [], strips: [])
        let strips = MixerLayout.visibleStrips(mix: mix, slots: slots, sources: [])
        #expect(strips.count == 1)
        #expect(strips[0].title == "Input 1")
    }

    @Test func midiMapsVelocityAcrossGainRangeAndMuteThreshold() {
        let range = -80.0...6.0
        #expect(Scarlett18i20Gen2Model.midiToDb(0, range: range) == -80)
        #expect(Scarlett18i20Gen2Model.midiToDb(127, range: range) == 6)
        #expect(Scarlett18i20Gen2Model.midiToMute(63) == false)
        #expect(Scarlett18i20Gen2Model.midiToMute(64) == true)
    }
}
