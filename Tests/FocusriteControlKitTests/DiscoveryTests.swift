import Testing
@testable import FocusriteControlKit

struct DiscoveryTests {
    @Test func parsePortAcceptsSingleAndDoubleQuotes() {
        #expect(DiscoveryService.parsePort(from: "<server-announcement port='49152'/>") == 49152)
        #expect(DiscoveryService.parsePort(from: #"<server-announcement port="49153"/>"#) == 49153)
        #expect(DiscoveryService.parsePort(from: "<server-announcement hostname='studio'/>") == nil)
        #expect(DiscoveryService.parsePort(from: "") == nil)
    }
}
