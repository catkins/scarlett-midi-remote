import Foundation
import Testing
@testable import FocusriteControlKit

struct ProtocolFramingTests {
    private let framing = ProtocolFraming()

    @Test func encodeUsesSixDigitHexLengthHeader() {
        let xml = "<keep-alive/>"
        let data = framing.encode(xml: xml)
        let encoded = String(decoding: data, as: UTF8.self)
        let expectedPrefix = "Length=" + String(format: "%06X", xml.utf8.count) + " "
        #expect(encoded == expectedPrefix + xml)
        #expect(expectedPrefix.count == "Length=".count + 6 + 1)
    }

    @Test func encodeThenParseRoundTrips() {
        let xml = #"<client-details hostname="Scarlett MIDI Control" client-key="abc-123"/>"#
        var buffer = framing.encode(xml: xml)
        let frames = framing.tryParseFrames(from: &buffer)
        #expect(frames == [xml])
        #expect(buffer.isEmpty)
    }

    @Test func parseConcatenatedHeaderOnlyFrames() {
        let first = "<keep-alive/>"
        let second = #"<client-details id="c1"/>"#
        var buffer = framing.encode(xml: first) + framing.encode(xml: second)
        let frames = framing.tryParseFrames(from: &buffer)
        #expect(frames == [first, second])
        #expect(buffer.isEmpty)
    }

    @Test func parseAcceptsOptionalFooter() {
        let xml = "<keep-alive/>"
        let length = xml.utf8.count
        let header = "Length=" + String(format: "%06X", length) + " "
        let footer = " Length=" + String(format: "%06X", length)
        var buffer = Data((header + xml + footer).utf8)
        let frames = framing.tryParseFrames(from: &buffer)
        #expect(frames == [xml])
        #expect(buffer.isEmpty)
    }

    @Test func parseLeavesIncompleteFrameInBuffer() {
        var buffer = Data("Length=0000FF <partial".utf8)
        let frames = framing.tryParseFrames(from: &buffer)
        #expect(frames.isEmpty)
        #expect(!buffer.isEmpty)
    }
}
