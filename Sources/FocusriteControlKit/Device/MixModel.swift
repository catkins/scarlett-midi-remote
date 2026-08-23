import Foundation

func mixerDisplayName(nickname: String, factoryName: String) -> String {
    let nick = nickname.trimmingCharacters(in: .whitespaces)
    return nick.isEmpty ? factoryName : nick
}

public struct MixSourceNode: Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var factoryName: String
    public var stereoName: String
    public var nickname: String
    public var nicknameId: String?
    public var meterParamId: String?

    public var displayName: String {
        mixerDisplayName(nickname: nickname, factoryName: factoryName)
    }

    public init(id: String,
                kind: String,
                factoryName: String,
                stereoName: String = "",
                nickname: String = "",
                nicknameId: String? = nil,
                meterParamId: String? = nil) {
        self.id = id
        self.kind = kind
        self.factoryName = factoryName
        self.stereoName = stereoName
        self.nickname = nickname
        self.nicknameId = nicknameId
        self.meterParamId = meterParamId
    }
}

public struct MixerSlotDescriptor: Equatable {
    public var sourceParamId: String
    public var stereoParamId: String

    public init(sourceParamId: String, stereoParamId: String) {
        self.sourceParamId = sourceParamId
        self.stereoParamId = stereoParamId
    }
}

public struct MixStripIDs: Equatable {
    public var gainId: String
    public var panId: String
    public var muteId: String
    public var soloId: String

    public init(gainId: String, panId: String, muteId: String, soloId: String) {
        self.gainId = gainId
        self.panId = panId
        self.muteId = muteId
        self.soloId = soloId
    }
}

public struct MixDescriptor: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var stereoName: String
    public var strips: [MixStripIDs]
    public var meterParamId: String

    public init(id: String, name: String, stereoName: String, strips: [MixStripIDs], meterParamId: String = "") {
        self.id = id
        self.name = name
        self.stereoName = stereoName
        self.strips = strips
        self.meterParamId = meterParamId
    }
}

public struct MixerSlotState: Equatable {
    public var sourceParamId: String
    public var stereoParamId: String
    public var sourceNodeId: String
    public var stereo: Bool

    public init(sourceParamId: String,
                stereoParamId: String,
                sourceNodeId: String = "",
                stereo: Bool = false) {
        self.sourceParamId = sourceParamId
        self.stereoParamId = stereoParamId
        self.sourceNodeId = sourceNodeId
        self.stereo = stereo
    }
}

public struct MixStripState: Equatable {
    public var gainDb: Double
    public var pan: Double
    public var muted: Bool
    public var solo: Bool

    public init(gainDb: Double = 0, pan: Double = 0, muted: Bool = false, solo: Bool = false) {
        self.gainDb = gainDb
        self.pan = pan
        self.muted = muted
        self.solo = solo
    }
}

public struct MixState: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var stereoName: String
    public var stripIDs: [MixStripIDs]
    public var strips: [MixStripState]
    public var meterParamId: String

    public init(id: String,
                name: String,
                stereoName: String,
                stripIDs: [MixStripIDs],
                strips: [MixStripState],
                meterParamId: String = "") {
        self.id = id
        self.name = name
        self.stereoName = stereoName
        self.stripIDs = stripIDs
        self.strips = strips
        self.meterParamId = meterParamId
    }
}

public struct VisibleMixStrip: Identifiable, Equatable {
    public var id: String
    public var mixId: String
    public var slotIndex: Int
    public var partnerSlotIndex: Int?
    public var title: String
    public var subtitle: String
    public var kind: String
    public var stereo: Bool
    public var gainDb: Double
    public var muted: Bool
    public var solo: Bool
    public var meterParamId: String?
    public var partnerMeterParamId: String?

    public init(
        id: String,
        mixId: String,
        slotIndex: Int,
        partnerSlotIndex: Int? = nil,
        title: String,
        subtitle: String = "",
        kind: String,
        stereo: Bool,
        gainDb: Double,
        muted: Bool,
        solo: Bool,
        meterParamId: String? = nil,
        partnerMeterParamId: String? = nil
    ) {
        self.id = id
        self.mixId = mixId
        self.slotIndex = slotIndex
        self.partnerSlotIndex = partnerSlotIndex
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.stereo = stereo
        self.gainDb = gainDb
        self.muted = muted
        self.solo = solo
        self.meterParamId = meterParamId
        self.partnerMeterParamId = partnerMeterParamId
    }

    public var meterIds: [String] {
        [meterParamId, partnerMeterParamId].compactMap { id in
            guard let id, !id.isEmpty else { return nil }
            return id
        }
    }
}

public struct OutputPair: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var kind: String
    public var leftId: String
    public var rightId: String?
    public var isMonitor: Bool
    public var assignedMixId: String
    public var gainDb: Double
    public var muted: Bool
    public var meterParamId: String?

    public init(
        id: String,
        title: String,
        kind: String,
        leftId: String,
        rightId: String? = nil,
        isMonitor: Bool,
        assignedMixId: String,
        gainDb: Double = 0,
        muted: Bool = false,
        meterParamId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.leftId = leftId
        self.rightId = rightId
        self.isMonitor = isMonitor
        self.assignedMixId = assignedMixId
        self.gainDb = gainDb
        self.muted = muted
        self.meterParamId = meterParamId
    }
}

public enum MixerLayout {
    /// Stereo-linked mixer slots collapse to one strip / one fader.
    public static func visibleStrips(
        mix: MixState,
        slots: [MixerSlotState],
        sources: [MixSourceNode]
    ) -> [VisibleMixStrip] {
        let sourceById = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        var result: [VisibleMixStrip] = []
        var index = 0
        while index < slots.count {
            let slot = slots[index]
            if slot.sourceNodeId.isEmpty {
                index += 1
                continue
            }
            let linked = slot.stereo && index + 1 < slots.count
            let partner = linked ? index + 1 : nil
            let source = sourceById[slot.sourceNodeId]
            let title: String
            if let source {
                if linked, !source.stereoName.isEmpty, source.nickname.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = source.stereoName
                } else {
                    title = source.displayName
                }
            } else {
                title = "Input \(index + 1)"
            }
            let strip = mix.strips.indices.contains(index) ? mix.strips[index] : MixStripState()
            var partnerMeter: String?
            if linked, let source, let sourceIndex = sources.firstIndex(where: { $0.id == source.id }), sourceIndex + 1 < sources.count {
                partnerMeter = sources[sourceIndex + 1].meterParamId
            }
            result.append(
                VisibleMixStrip(
                    id: "\(mix.id)-\(index)",
                    mixId: mix.id,
                    slotIndex: index,
                    partnerSlotIndex: partner,
                    title: title,
                    subtitle: source?.factoryName ?? "",
                    kind: source?.kind ?? "",
                    stereo: linked,
                    gainDb: strip.gainDb,
                    muted: strip.muted,
                    solo: strip.solo,
                    meterParamId: source?.meterParamId,
                    partnerMeterParamId: partnerMeter
                )
            )
            index += linked ? 2 : 1
        }
        return result
    }

    public static func outputPairs(from outputs: [DeviceChannel]) -> [OutputPair] {
        var pairs: [OutputPair] = []
        var skipNext = false
        for (index, channel) in outputs.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            let linked = channel.stereoLinked && !channel.stereoName.isEmpty && index + 1 < outputs.count
            if linked { skipNext = true }
            let title: String
            if linked {
                let nick = channel.nickname.trimmingCharacters(in: .whitespaces)
                title = nick.isEmpty ? (channel.stereoName.isEmpty ? channel.displayName : channel.stereoName) : nick
            } else {
                title = channel.displayName
            }
            let isMonitor = channel.factoryName.lowercased().contains("monitor")
                || channel.stereoName.lowercased().contains("monitor")
            pairs.append(
                OutputPair(
                    id: channel.id,
                    title: title,
                    kind: channel.kind,
                    leftId: channel.id,
                    rightId: linked ? outputs[index + 1].id : nil,
                    isMonitor: isMonitor,
                    assignedMixId: channel.assignedMixId,
                    gainDb: channel.gainDb,
                    muted: channel.muted,
                    meterParamId: channel.meterParamId
                )
            )
        }
        return pairs
    }

    public static func leftMix(forMixId mixId: String, in mixes: [MixState]) -> MixState? {
        guard let mix = mixes.first(where: { $0.id == mixId }) else { return nil }
        if !mix.stereoName.isEmpty { return mix }
        return mixes.first(where: { $0.name == mix.name && !$0.stereoName.isEmpty }) ?? mix
    }

    public static func partnerMix(for mix: MixState, in mixes: [MixState]) -> MixState? {
        mixes.first { $0.name == mix.name && $0.id != mix.id }
    }

    /// Slot indices written for one fader: this slot and, when linked, the next slot.
    public static func writeSlotIndices(slotIndex: Int, stereo: Bool, stripCount: Int) -> [Int] {
        var indices = [slotIndex]
        if stereo {
            let partner = slotIndex + 1
            if partner < stripCount { indices.append(partner) }
        }
        return indices
    }

    /// Mix + slot pairs written for one strip fader/mute/solo, including the paired R mix.
    public static func writeTargets(
        mixId: String,
        slotIndex: Int,
        mixes: [MixState],
        slots: [MixerSlotState]
    ) -> [MixWriteTarget] {
        guard let left = leftMix(forMixId: mixId, in: mixes),
              let leftIndex = mixes.firstIndex(where: { $0.id == left.id }) else { return [] }
        let stereo = slots.indices.contains(slotIndex) && slots[slotIndex].stereo
        let slotIndices = writeSlotIndices(
            slotIndex: slotIndex,
            stereo: stereo,
            stripCount: mixes[leftIndex].strips.count
        )
        var mixIndices = [leftIndex]
        if let partner = partnerMix(for: mixes[leftIndex], in: mixes),
           let partnerIndex = mixes.firstIndex(where: { $0.id == partner.id }) {
            mixIndices.append(partnerIndex)
        }
        var targets: [MixWriteTarget] = []
        for mixIndex in mixIndices {
            for slot in slotIndices where mixes[mixIndex].strips.indices.contains(slot) {
                targets.append(MixWriteTarget(mixIndex: mixIndex, slotIndex: slot))
            }
        }
        return targets
    }

    /// Compact VU fill 0...1. Live meters are dBFS; −128 is digital silence.
    public static func meterFill(db: Double, floor: Double = -60, ceiling: Double = 0) -> Double {
        min(max((db - floor) / (ceiling - floor), 0), 1)
    }

    /// Snap meter dB to 0.5 so tiny server jitter does not republish.
    public static func quantizeMeter(_ db: Double) -> Double {
        (db * 2).rounded() / 2
    }

    /// Fast-path for inbound `<item>` values that are known meters.
    public static func applyMeterItem(
        id: String,
        value: String,
        meterIds: Set<String>,
        meters: inout [String: Double]
    ) -> MeterItemApply {
        guard meterIds.contains(id), let db = Double(value) else { return .ignored }
        let quantized = quantizeMeter(db)
        if meters[id] == quantized { return .unchanged }
        meters[id] = quantized
        return .updated
    }
}

public struct MixWriteTarget: Equatable {
    public var mixIndex: Int
    public var slotIndex: Int

    public init(mixIndex: Int, slotIndex: Int) {
        self.mixIndex = mixIndex
        self.slotIndex = slotIndex
    }
}

public enum MeterItemApply: Equatable {
    case ignored
    case unchanged
    case updated
}
