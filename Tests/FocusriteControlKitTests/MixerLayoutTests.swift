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
                  <input><gain id="55"/><pan id="56"/><mute id="57"/><solo id="58"/></input>
                  <input><gain id="59"/><pan id="60"/><mute id="61"/><solo id="62"/></input>
                </mix>
              </mixes>
            </mixer>
            <inputs>
              <analogue id="795" name="Analogue 1" stereo-name="Analogue 1-2">
                <nickname id="796"/>
              </analogue>
              <playback id="867" name="Playback 1" stereo-name="Playback 1-2">
                <nickname id="868"/>
              </playback>
            </inputs>
            <outputs>
              <analogue name="Monitor Output 1" stereo-name="Monitor Outputs 1-2">
                <source id="952"/><mute id="951"/><gain id="956"/><stereo id="953"/>
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
    }
}
