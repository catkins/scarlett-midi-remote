import SwiftUI
import Combine
import FocusriteControlKit

struct DeviceView: View {
    @StateObject private var viewModel = DeviceViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.deviceModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.requestSnapshot()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!viewModel.canRefresh)
                .help("Refresh device snapshot")
            }

            if viewModel.visibleOutputs.isEmpty {
                Text("No outputs to show. Enable some in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Output", selection: $viewModel.selectedOutputId) {
                    ForEach(viewModel.visibleOutputs) { pair in
                        Text(pair.title).tag(pair.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: viewModel.selectedOutputId) { _, _ in
                    viewModel.outputSelectionChanged()
                }

                if viewModel.selectedOutput != nil {
                    VolumeFader(value: $viewModel.masterDb, title: viewModel.selectedOutput?.isMonitor == true ? "Monitor" : "Level", range: viewModel.gainRange) { editing in
                        viewModel.masterSliderChanged(editing: editing)
                    }
                    .onChange(of: viewModel.masterDb) { _, _ in
                        viewModel.masterValueChanged()
                    }

                    Toggle("Mute", isOn: $viewModel.masterMute)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: viewModel.masterMute) { _, newValue in
                            viewModel.userChangedMasterMute(newValue)
                        }
                }
            }

            let hardware = viewModel.mixStrips.filter { $0.kind != "playback" }
            let playback = viewModel.mixStrips.filter { $0.kind == "playback" }

            if !hardware.isEmpty || !playback.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !hardware.isEmpty {
                            Text("Hardware inputs")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(hardware) { strip in
                                MixStripRow(strip: strip, range: viewModel.mixRange) { db in
                                    viewModel.setMixGain(strip: strip, db: db)
                                } onMute: { muted in
                                    viewModel.setMixMute(strip: strip, muted: muted)
                                } onSolo: { solo in
                                    viewModel.setMixSolo(strip: strip, solo: solo)
                                }
                            }
                        }
                        if !playback.isEmpty {
                            Text("Playback")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                            ForEach(playback) { strip in
                                MixStripRow(strip: strip, range: viewModel.mixRange) { db in
                                    viewModel.setMixGain(strip: strip, db: db)
                                } onMute: { muted in
                                    viewModel.setMixMute(strip: strip, muted: muted)
                                } onSolo: { solo in
                                    viewModel.setMixSolo(strip: strip, solo: solo)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            } else if viewModel.selectedOutput != nil {
                Text("No sources assigned to this mix in Focusrite Control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.showApprovalHint {
                Text("Approve “Scarlett MIDI Control” in Focusrite Control → Settings → Remote Devices if faders don’t stick.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
}

struct VolumeFader: View {
    @Binding var value: Double
    let title: String
    var range: ClosedRange<Double> = -80...10
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)
            Slider(value: $value, in: range, step: 0.5, onEditingChanged: onEditingChanged)
            Text(String(format: "%5.1f dB", value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }
}

private struct MixStripRow: View {
    let strip: VisibleMixStrip
    let range: ClosedRange<Double>
    let onGain: (Double) -> Void
    let onMute: (Bool) -> Void
    let onSolo: (Bool) -> Void
    @State private var gain: Double = 0
    @State private var muted = false
    @State private var solo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(strip.title)
                    .font(.caption)
                    .lineLimit(1)
                if strip.stereo {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Stereo linked — one fader")
                }
                Spacer()
                Button {
                    muted.toggle()
                    onMute(muted)
                } label: {
                    Text("M")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(muted ? Color.white : Color.secondary)
                        .frame(width: 18, height: 18)
                        .background(muted ? Color.red.opacity(0.85) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Mute")
                Button {
                    solo.toggle()
                    onSolo(solo)
                } label: {
                    Text("S")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(solo ? Color.white : Color.secondary)
                        .frame(width: 18, height: 18)
                        .background(solo ? Color.yellow.opacity(0.9) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Solo")
            }
            HStack(spacing: 8) {
                Slider(value: $gain, in: range, step: 0.5) { _ in
                    onGain(gain)
                }
                Text(String(format: "%4.1f", gain))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .onAppear {
            gain = strip.gainDb
            muted = strip.muted
            solo = strip.solo
        }
        .onChange(of: strip.gainDb) { _, value in gain = value }
        .onChange(of: strip.muted) { _, value in muted = value }
        .onChange(of: strip.solo) { _, value in solo = value }
    }
}

final class DeviceViewModel: ObservableObject {
    @Published var deviceModel: String = "Scarlett 18i20 · 2nd Gen"
    @Published var masterDb: Double = -10
    @Published var masterMute: Bool = false
    @Published var gainRange: ClosedRange<Double> = -80...10
    @Published var mixRange: ClosedRange<Double> = -80...6
    @Published var showApprovalHint = true
    @Published var canRefresh = false
    @Published var selectedOutputId: String = ""
    @Published var visibleOutputs: [OutputPair] = []
    @Published var mixStrips: [VisibleMixStrip] = []

    var selectedOutput: OutputPair? {
        visibleOutputs.first(where: { $0.id == selectedOutputId }) ?? visibleOutputs.first
    }

    private var appState: AppState?
    private var applyingRemote = false
    private var draggingMaster = false
    private var latest = Scarlett18i20Gen2Model()
    private var cancellables = Set<AnyCancellable>()

    func bind(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState

        appState.controlClient.devicePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.apply(model: model)
            }
            .store(in: &cancellables)

        appState.controlClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.canRefresh = (state == .connected || state == .awaitingApproval)
                self?.showApprovalHint = (state != .connected)
            }
            .store(in: &cancellables)

        appState.$hiddenOutputIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshDerived(from: self.latest)
            }
            .store(in: &cancellables)
    }

    func requestSnapshot() {
        appState?.controlClient.requestDeviceSnapshot()
    }

    func outputSelectionChanged() {
        refreshDerived(from: latest)
    }

    func masterSliderChanged(editing: Bool) {
        draggingMaster = editing
        sendMasterGain()
        if !editing { draggingMaster = false }
    }

    func masterValueChanged() {
        guard !applyingRemote else { return }
        sendMasterGain()
    }

    func userChangedMasterMute(_ enabled: Bool) {
        guard !applyingRemote else { return }
        guard let selected = selectedOutput else { return }
        if selected.isMonitor {
            appState?.controlClient.setMonitorMute(enabled)
        } else {
            appState?.controlClient.setOutputMute(id: selected.leftId, enabled: enabled)
        }
    }

    func setMixGain(strip: VisibleMixStrip, db: Double) {
        appState?.controlClient.setMixGain(mixId: strip.mixId, slotIndex: strip.slotIndex, db: db)
    }

    func setMixMute(strip: VisibleMixStrip, muted: Bool) {
        appState?.controlClient.setMixMute(mixId: strip.mixId, slotIndex: strip.slotIndex, enabled: muted)
    }

    func setMixSolo(strip: VisibleMixStrip, solo: Bool) {
        appState?.controlClient.setMixSolo(mixId: strip.mixId, slotIndex: strip.slotIndex, enabled: solo)
    }

    private func sendMasterGain() {
        guard let selected = selectedOutput else { return }
        if selected.isMonitor {
            appState?.controlClient.setMonitorDb(masterDb)
        } else {
            appState?.controlClient.setOutputGain(id: selected.leftId, db: masterDb)
        }
    }

    private func apply(model: Scarlett18i20Gen2Model) {
        applyingRemote = true
        latest = model
        if !model.deviceModel.isEmpty {
            deviceModel = model.deviceModel
        }
        gainRange = model.gainRange
        mixRange = model.mixGainRange
        refreshDerived(from: model)
        applyingRemote = false
    }

    private func refreshDerived(from model: Scarlett18i20Gen2Model) {
        let pairs = model.outputPairs()
        visibleOutputs = pairs.filter { isVisible($0) }
        if visibleOutputs.contains(where: { $0.id == selectedOutputId }) == false {
            selectedOutputId = visibleOutputs.first?.id ?? ""
        }
        guard let selected = selectedOutput else {
            mixStrips = []
            return
        }
        if !draggingMaster {
            if selected.isMonitor {
                masterDb = min(max(model.monitorDb, gainRange.lowerBound), gainRange.upperBound)
                masterMute = model.monitorMute
            } else {
                masterDb = min(max(selected.gainDb, gainRange.lowerBound), gainRange.upperBound)
                masterMute = selected.muted
            }
        }
        mixStrips = model.visibleStrips(forMixId: selected.assignedMixId)
    }

    private func isVisible(_ pair: OutputPair) -> Bool {
        guard let appState else { return pair.kind == "analogue" }
        if appState.didCustomizeHiddenOutputs {
            return !appState.hiddenOutputIds.contains(pair.id)
        }
        return pair.kind == "analogue"
    }
}
