import Testing
@testable import FocusriteControlKit

struct DeviceXMLTests {
    @Test func parseSetItemsExtractsDeviceAndItems() {
        let xml = #"<set devid="1"><item id="1127" value="-27"/><item id="1129" value="true"/></set>"#
        let parsed = DeviceXML.parseSetItems(xml)
        #expect(parsed?.deviceId == "1")
        #expect(parsed?.items.count == 2)
        #expect(parsed?.items.first?.id == "1127")
        #expect(parsed?.items.first?.value == "-27")
        #expect(parsed?.items.last?.id == "1129")
        #expect(parsed?.items.last?.value == "true")
    }

    @Test func parseSetItemsReturnsNilWithoutSetElement() {
        #expect(DeviceXML.parseSetItems("<keep-alive/>") == nil)
    }

    @Test func setMessageFormatsDeviceAndItems() {
        let xml = DeviceXML.setMessage(
            deviceId: "1",
            items: [("1127", "-27"), ("1129", "true")]
        )
        #expect(xml == #"<set devid="1"><item id="1127" value="-27"/><item id="1129" value="true"/></set>"#)
    }

    @Test func subscribeMessageIncludesDeviceId() {
        #expect(DeviceXML.subscribeMessage(deviceId: "1") == #"<device-subscribe devid="1" subscribe="true"/>"#)
    }

    @Test func parseArrivalReturnsDeviceIdFromSyntheticFixture() {
        let xml = """
        <device-arrival>
          <device id="1" model="Scarlett 18i20 2nd Gen">
            <inputs>
              <analogue name="Analogue 1" stereo-name="Analogue 1|2">
                <nickname id="100"/>
                <available id="101"/>
                <gain id="103"/>
              </analogue>
            </inputs>
            <outputs>
              <analogue name="Monitor Output 1" stereo-name="Monitor Output 1|2">
                <mute id="201"/>
                <gain id="202"/>
              </analogue>
            </outputs>
            <monitoring>
              <hardware-controls min-gain="-128" max-gain="0">
                <gain id="1127"/>
                <mute id="1129"/>
                <dim id="1130"/>
              </hardware-controls>
            </monitoring>
          </device>
        </device-arrival>
        """
        let map = DeviceXML.parseArrival(xml)
        #expect(map?.deviceId == "1")
    }
}
