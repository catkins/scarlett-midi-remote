import Foundation

public struct MixSourceNode: Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var factoryName: String
    public var stereoName: String
    public var nickname: String
    public var nicknameId: String?

    public var displayName: String {
        let nick = nickname.trimmingCharacters(in: .whitespaces)
        return nick.isEmpty ? factoryName : nick
    }

    public init(id: String,
                kind: String,
                factoryName: String,
                stereoName: String = "",
                nickname: String = "",
                nicknameId: String? = nil) {
        self.id = id
        self.kind = kind
        self.factoryName = factoryName
        self.stereoName = stereoName
        self.nickname = nickname
        self.nicknameId = nicknameId
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

    public init(id: String, name: String, stereoName: String, strips: [MixStripIDs]) {
        self.id = id
        self.name = name
        self.stereoName = stereoName
        self.strips = strips
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

    public init(id: String,
                name: String,
                stereoName: String,
                stripIDs: [MixStripIDs],
                strips: [MixStripState]) {
        self.id = id
        self.name = name
        self.stereoName = stereoName
        self.stripIDs = stripIDs
        self.strips = strips
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
                    solo: strip.solo
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
                    muted: channel.muted
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

    /// Slot indices written for one fader: this slot, stereo partner, and matching slots on the R mix.
    public static func writeSlotIndices(slotIndex: Int, stereo: Bool, stripCount: Int) -> [Int] {
        var indices = [slotIndex]
        if stereo {
            let partner = slotIndex + 1
            if partner < stripCount { indices.append(partner) }
        }
        return indices
    }
}
