import Foundation

public struct Scarlett18i20Gen2Model: Equatable {
    public var deviceId: String
    public var deviceModel: String
    /// Hardware monitor is a stereo pair. The app keeps L/R identical.
    public var monitorDb: Double
    public var monitorMute: Bool
    public var minGainDb: Double
    public var maxGainDb: Double
    public var mixMinGainDb: Double
    public var mixMaxGainDb: Double
    public var inputs: [DeviceChannel]
    public var outputs: [DeviceChannel]
    public var mixerSlots: [MixerSlotState]
    public var mixes: [MixState]
    public var sourceNodes: [MixSourceNode]

    public var gainRange: ClosedRange<Double> { min(minGainDb, maxGainDb)...max(minGainDb, maxGainDb) }
    public var mixGainRange: ClosedRange<Double> { min(mixMinGainDb, mixMaxGainDb)...max(mixMinGainDb, mixMaxGainDb) }

    public var monitorLeftDb: Double { monitorDb }
    public var monitorRightDb: Double { monitorDb }

    public init(deviceId: String = "",
                deviceModel: String = "Scarlett 18i20 (2nd Gen)",
                monitorDb: Double = -10,
                monitorMute: Bool = false,
                minGainDb: Double = -80,
                maxGainDb: Double = 10,
                mixMinGainDb: Double = -80,
                mixMaxGainDb: Double = 6,
                inputs: [DeviceChannel] = [],
                outputs: [DeviceChannel] = [],
                mixerSlots: [MixerSlotState] = [],
                mixes: [MixState] = [],
                sourceNodes: [MixSourceNode] = []) {
        self.deviceId = deviceId
        self.deviceModel = deviceModel
        self.monitorDb = monitorDb
        self.monitorMute = monitorMute
        self.minGainDb = minGainDb
        self.maxGainDb = maxGainDb
        self.mixMinGainDb = mixMinGainDb
        self.mixMaxGainDb = mixMaxGainDb
        self.inputs = inputs
        self.outputs = outputs
        self.mixerSlots = mixerSlots
        self.mixes = mixes
        self.sourceNodes = sourceNodes
    }

    public func outputPairs() -> [OutputPair] {
        MixerLayout.outputPairs(from: outputs)
    }

    public func visibleStrips(forMixId mixId: String) -> [VisibleMixStrip] {
        guard let mix = MixerLayout.leftMix(forMixId: mixId, in: mixes) else { return [] }
        return MixerLayout.visibleStrips(mix: mix, slots: mixerSlots, sources: sourceNodes)
    }

    public static func midiToDb(_ value: UInt8, range: ClosedRange<Double>) -> Double {
        let t = Double(value) / 127.0
        let db = range.lowerBound + t * (range.upperBound - range.lowerBound)
        return (db * 2).rounded() / 2
    }

    public static func midiToMute(_ value: UInt8) -> Bool { value >= 64 }
}
