import Foundation

/// High-level model of Scarlett 18i20 (2nd Gen) parameters as exposed via Control server.
/// This is intentionally conservative until verified against a live device.
public struct Scarlett18i20Gen2Model: Codable, Equatable {
    public var monitorLeftDb: Double
    public var monitorRightDb: Double
    public var monitorMute: Bool
    
    public init(monitorLeftDb: Double = -10,
                monitorRightDb: Double = -10,
                monitorMute: Bool = false) {
        self.monitorLeftDb = monitorLeftDb
        self.monitorRightDb = monitorRightDb
        self.monitorMute = monitorMute
    }
}

