import SwiftUI
import FocusriteControlKit
import MidiKit

struct MixerDisplayState {
    var deviceModel: String
    var outputs: [OutputPair]
    var selectedOutputId: String
    var masterTitle: String
    var masterDb: Double
    var masterMute: Bool
    var gainRange: ClosedRange<Double>
    var mixRange: ClosedRange<Double>
    var hardware: [VisibleMixStrip]
    var playback: [VisibleMixStrip]
    var canRefresh: Bool
    var learnArmed: Bool
    var pendingLearnId: String?
    var mappedIds: Set<String>
    var masterGainTargetId: String
    var masterMuteTargetId: String
    var masterMeterIds: [String]
}

struct MixerPanel: View {
    let state: MixerDisplayState
    @Binding var masterDb: Double
    var onSelectOutput: (String) -> Void
    var onRefresh: () -> Void
    var onMasterEditing: (Bool) -> Void
    var onMasterMute: (Bool) -> Void
    var onLearn: (String, String) -> Void
    var onStripGain: (VisibleMixStrip, Double) -> Void
    var onStripMute: (VisibleMixStrip, Bool) -> Void
    var onStripSolo: (VisibleMixStrip, Bool) -> Void
    @Environment(\.highlightSwatch) private var swatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(state.deviceModel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!state.canRefresh)
                .opacity(state.canRefresh ? 1 : 0.35)
                .help("Refresh device snapshot")
            }

            if state.outputs.isEmpty {
                Text("No outputs to show. Enable some in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                OutputSwitcher(
                    outputs: state.outputs,
                    selectedId: state.selectedOutputId,
                    onSelect: onSelectOutput
                )

                masterRow
            }

            stripGroup(title: "Hardware", strips: state.hardware)
            stripGroup(title: "Playback", strips: state.playback)

            if state.hardware.isEmpty, state.playback.isEmpty, !state.outputs.isEmpty {
                Text("No sources assigned to this mix in Focusrite Control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var masterRow: some View {
        HStack(spacing: 8) {
            learnHit(state.masterGainTargetId, name: "\(state.masterTitle) · Level") {
                Text(state.masterTitle)
                    .font(ConsoleTheme.strip)
                    .foregroundStyle(state.masterMute ? Color.secondary.opacity(0.55) : Color.primary)
                    .lineLimit(1)
                    .frame(width: 72, alignment: .leading)
            }
            VStack(spacing: 3) {
                ConsoleFader(
                    value: $masterDb,
                    range: state.gainRange,
                    muted: state.masterMute,
                    armed: state.pendingLearnId == state.masterGainTargetId
                ) { editing in
                    if editing {
                        onLearn(state.masterGainTargetId, "\(state.masterTitle) · Level")
                    }
                    onMasterEditing(editing)
                }
                ConsoleMeter(ids: state.masterMeterIds, muted: state.masterMute)
            }
            Text(String(format: "%5.1f", masterDb))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            mappedDot(state.masterGainTargetId)
            ConsoleFlag(
                letter: "M",
                active: state.masterMute,
                activeColor: ConsoleTheme.mute
            ) {
                onLearn(state.masterMuteTargetId, "\(state.masterTitle) · Mute")
                onMasterMute(!state.masterMute)
            }
            .help("Mute \(state.masterTitle)")
            .overlay(learnRing(state.masterMuteTargetId))
        }
    }

    @ViewBuilder
    private func stripGroup(title: String, strips: [VisibleMixStrip]) -> some View {
        if !strips.isEmpty {
            ConsoleHairline()
                .padding(.vertical, 2)
            VStack(spacing: 4) {
                ForEach(strips) { strip in
                    MixStripRow(
                        strip: strip,
                        outputTitle: state.masterTitle,
                        range: state.mixRange,
                        pendingLearnId: state.pendingLearnId,
                        mappedIds: state.mappedIds,
                        onLearn: onLearn,
                        onGain: { onStripGain(strip, $0) },
                        onMute: { onStripMute(strip, $0) },
                        onSolo: { onStripSolo(strip, $0) }
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }

    private func mappedDot(_ id: String) -> some View {
        Circle()
            .fill(state.mappedIds.contains(id) ? swatch.color : Color.clear)
            .frame(width: 5, height: 5)
            .help(state.mappedIds.contains(id) ? "MIDI mapped" : "")
    }

    private func learnRing(_ id: String) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(state.pendingLearnId == id ? swatch.color : Color.clear, lineWidth: 1.5)
            .padding(-2)
    }

    private func learnHit<Content: View>(_ id: String, name: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture { onLearn(id, name) }
            .overlay(learnRing(id))
    }
}

struct OutputSwitcher: View {
    let outputs: [OutputPair]
    let selectedId: String
    let onSelect: (String) -> Void
    @Environment(\.highlightSwatch) private var swatch

    private var rows: [[OutputPair]] {
        stride(from: 0, to: outputs.count, by: 3).map {
            Array(outputs[$0..<min($0 + 3, outputs.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    Rectangle()
                        .fill(ConsoleTheme.wellStroke)
                        .frame(height: 1)
                }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, pair in
                        if index > 0 {
                            Rectangle()
                                .fill(ConsoleTheme.wellStroke)
                                .frame(width: 1)
                        }
                        Button {
                            onSelect(pair.id)
                        } label: {
                            Text(pair.title)
                                .font(ConsoleTheme.chip)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(Color.primary.opacity(pair.id == selectedId ? 1 : 0.9))
                                .background(pair.id == selectedId ? swatch.color.opacity(0.38) : Color.primary.opacity(0.001))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .help(pair.title)
                        .accessibilityAddTraits(pair.id == selectedId ? .isSelected : [])
                    }
                }
                .frame(height: 26)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(ConsoleTheme.wellStroke, lineWidth: 1)
        )
    }
}

private struct MixStripRow: View {
    let strip: VisibleMixStrip
    let outputTitle: String
    let range: ClosedRange<Double>
    let pendingLearnId: String?
    let mappedIds: Set<String>
    let onLearn: (String, String) -> Void
    let onGain: (Double) -> Void
    let onMute: (Bool) -> Void
    let onSolo: (Bool) -> Void
    @Environment(\.highlightSwatch) private var swatch
    @State private var gain: Double = 0
    @State private var muted = false
    @State private var solo = false

    private var trackLabel: String {
        let left = strip.slotIndex + 1
        if strip.stereo {
            let right = (strip.partnerSlotIndex ?? strip.slotIndex + 1) + 1
            return "\(left)/\(right)"
        }
        return String(left)
    }

    private var gainId: String { MidiTarget.mixGain(mixId: strip.mixId, slot: strip.slotIndex).id }
    private var muteId: String { MidiTarget.mixMute(mixId: strip.mixId, slot: strip.slotIndex).id }
    private var soloId: String { MidiTarget.mixSolo(mixId: strip.mixId, slot: strip.slotIndex).id }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Text(trackLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)
                HStack(spacing: 3) {
                    Text(strip.title)
                        .font(ConsoleTheme.strip)
                        .foregroundStyle(muted ? Color.secondary.opacity(0.55) : Color.primary)
                        .lineLimit(1)
                    if strip.stereo {
                        Image(systemName: "link")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .help("Stereo linked — one fader")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 118, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onLearn(gainId, "\(outputTitle) · \(strip.title)") }

            VStack(spacing: 3) {
                ConsoleFader(
                    value: $gain,
                    range: range,
                    muted: muted,
                    armed: pendingLearnId == gainId
                ) { editing in
                    if editing {
                        onLearn(gainId, "\(outputTitle) · \(strip.title)")
                    }
                    onGain(gain)
                }
                .onChange(of: gain) { _, value in
                    onGain(value)
                }
                ConsoleMeter(ids: strip.meterIds, muted: muted)
            }

            Text(String(format: "%4.1f", gain))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            Circle()
                .fill(mappedIds.contains(gainId) ? swatch.color : Color.clear)
                .frame(width: 5, height: 5)

            ConsoleFlag(letter: "M", active: muted, activeColor: ConsoleTheme.mute) {
                muted.toggle()
                onLearn(muteId, "\(outputTitle) · \(strip.title) mute")
                onMute(muted)
            }
            .help("Mute")
            .overlay(ring(muteId))

            ConsoleFlag(letter: "S", active: solo, activeColor: ConsoleTheme.solo) {
                solo.toggle()
                onLearn(soloId, "\(outputTitle) · \(strip.title) solo")
                onSolo(solo)
            }
            .help("Solo")
            .overlay(ring(soloId))
        }
        .onAppear { syncFromStrip() }
        .onChange(of: strip.gainDb) { _, value in gain = value }
        .onChange(of: strip.muted) { _, value in muted = value }
        .onChange(of: strip.solo) { _, value in solo = value }
    }

    private func syncFromStrip() {
        gain = strip.gainDb
        muted = strip.muted
        solo = strip.solo
    }

    private func ring(_ id: String) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(pendingLearnId == id ? swatch.color : Color.clear, lineWidth: 1.5)
            .padding(-2)
    }
}
