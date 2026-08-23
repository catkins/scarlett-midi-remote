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

    @Test func parseSetItemsKeepsEmptyValuesAndMissingDeviceId() {
        let emptyValue = DeviceXML.parseSetItems(#"<set devid="1"><item id="18" value=""/></set>"#)
        #expect(emptyValue?.deviceId == "1")
        #expect(emptyValue?.items.count == 1)
        #expect(emptyValue?.items.first?.id == "18")
        #expect(emptyValue?.items.first?.value == "")

        let noItems = DeviceXML.parseSetItems(#"<set devid="1"></set>"#)
        #expect(noItems?.deviceId == "1")
        #expect(noItems?.items.isEmpty == true)

        let noDevid = DeviceXML.parseSetItems(#"<set><item id="1127" value="-27"/></set>"#)
        #expect(noDevid?.deviceId == "")
        #expect(noDevid?.items.first?.id == "1127")
    }

    @Test func parseSetItemsIgnoresValueFirstAttributeOrder() {
        let parsed = DeviceXML.parseSetItems(#"<set devid="1"><item value="-27" id="1127"/></set>"#)
        #expect(parsed?.deviceId == "1")
        #expect(parsed?.items.isEmpty == true)
    }

    @Test func parseClientIdReadsClientDetails() {
        #expect(DeviceXML.parseClientId(#"<client-details id="c1" hostname="Mac"/>"#) == "c1")
        #expect(DeviceXML.parseClientId("<keep-alive/>") == nil)
    }

    @Test func parseApprovalAuthorisedAcceptsSpellings() {
        #expect(DeviceXML.parseApprovalAuthorised(#"<approval id="c1" authorised="true"/>"#) == true)
        #expect(DeviceXML.parseApprovalAuthorised(#"<approval authorized="1"/>"#) == true)
        #expect(DeviceXML.parseApprovalAuthorised(#"<approval authorised="false"/>"#) == false)
        #expect(DeviceXML.parseApprovalAuthorised("<keep-alive/>") == nil)
    }

    @Test func isTruthyRecognizesTrueAndOne() {
        #expect(DeviceXML.isTruthy("true"))
        #expect(DeviceXML.isTruthy("1"))
        #expect(!DeviceXML.isTruthy("false"))
        #expect(!DeviceXML.isTruthy("0"))
        #expect(!DeviceXML.isTruthy(""))
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
        #expect(map?.deviceModel == "Scarlett 18i20 2nd Gen")
        #expect(map?.hardwareGainId == "1127")
        #expect(map?.hardwareMuteId == "1129")
        #expect(map?.hardwareDimId == "1130")
        #expect(map?.minGainDb == -128)
        #expect(map?.maxGainDb == 0)
        #expect(map?.inputs.contains(where: { $0.factoryName == "Analogue 1" }) == true)
    }

    @Test func parseArrivalReturnsNilWithoutDeviceId() {
        let xml = """
        <device-arrival>
          <device model="Scarlett 18i20 2nd Gen"></device>
        </device-arrival>
        """
        #expect(DeviceXML.parseArrival(xml) == nil)
    }
}
