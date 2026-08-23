import Foundation
import Combine
import Darwin

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

/// UDP discovery as used by classic iOS Focusrite Control.
///
/// Verified locally: broadcasting (or unicasting to 127.0.0.1) on ports
/// 30096–30098 with a framed `<client-discovery>` payload yields
/// `<server-announcement … port='49152'/>`.
public final class DiscoveryService: DiscoveryServiceProtocol {
    public static let discoveryPorts: [UInt16] = [30096, 30097, 30098]
    
    private let subject = PassthroughSubject<DiscoveredServer, Never>()
    public var discoveredPublisher: AnyPublisher<DiscoveredServer, Never> { subject.eraseToAnyPublisher() }
    
    private let queue = DispatchQueue(label: "com.example.ScarlettMidiControl.discovery")
    private let framing = ProtocolFraming()
    
    public init() {}
    
    public func startDiscovery() {
        queue.async { [weak self] in
            self?.broadcastAndListen()
        }
    }
    
    private func broadcastAndListen() {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { close(fd) }
        
        var broadcastEnable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout.size(ofValue: broadcastEnable)))
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        
        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0
        bindAddr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        _ = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        
        let xml = #"<client-discovery app="SAFFIRE-CONTROL" version="4" device="iOS"/>"#
        let payload = framing.encode(xml: xml)
        
        let destinations: [(String, UInt16)] =
            ["127.0.0.1", "255.255.255.255"].flatMap { host in
                Self.discoveryPorts.map { (host, $0) }
            }
        for (host, port) in destinations {
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr = in_addr(s_addr: inet_addr(host))
            _ = withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    payload.withUnsafeBytes { raw in
                        sendto(fd, raw.baseAddress, payload.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        var src = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let received = withUnsafeMutablePointer(to: &src) { srcPtr -> Int in
            srcPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                recvfrom(fd, &buffer, buffer.count, 0, sockPtr, &srcLen)
            }
        }
        guard received > 0 else { return }
        
        var data = Data(buffer.prefix(received))
        let frames = framing.tryParseFrames(from: &data)
        let xmlText = frames.first ?? String(bytes: buffer.prefix(received), encoding: .utf8) ?? ""
        guard let port = Self.parsePort(from: xmlText) else { return }
        
        var addr = src.sin_addr
        var ipBytes = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &ipBytes, socklen_t(INET_ADDRSTRLEN))
        let ip = String(cString: ipBytes)
        let host = (ip == "0.0.0.0" || ip.isEmpty) ? "127.0.0.1" : ip
        subject.send(DiscoveredServer(host: host, port: port))
    }
    
    public static func parsePort(from xml: String) -> UInt16? {
        let patterns = [
            #"port\s*=\s*'(\d+)'"#,
            #"port\s*=\s*"(\d+)""#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml),
               let port = UInt16(xml[range]) {
                return port
            }
        }
        return nil
    }
}
