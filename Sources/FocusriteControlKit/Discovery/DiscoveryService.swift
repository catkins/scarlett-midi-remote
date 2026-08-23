import Foundation
import Combine

public protocol DiscoveryServiceProtocol {
    var discoveredPublisher: AnyPublisher<DiscoveredServer, Never> { get }
    func startDiscovery()
}

public struct DiscoveredServer: Equatable {
    public let host: String
    public let port: UInt16
    
    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

public final class DiscoveryService: DiscoveryServiceProtocol {
    private let subject = PassthroughSubject<DiscoveredServer, Never>()
    public var discoveredPublisher: AnyPublisher<DiscoveredServer, Never> { subject.eraseToAnyPublisher() }
    
    public init() {}
    
    public func startDiscovery() {
        // MVP stub: perform UDP broadcast to ports 30096, 30097, 30098
        // Protocol notes (UNVERIFIED): message like:
        // Length=<6hex> <client-discovery app="SAFFIRE-CONTROL" version="4" device="iOS"/>
        // We emit a placeholder and schedule a simulated callback to unblock UI while protocol is implemented.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [subject] in
            // Placeholder: localhost with a typical port; real code parses UDP XML response for the TCP port.
            subject.send(DiscoveredServer(host: "127.0.0.1", port: 49152))
        }
    }
}

