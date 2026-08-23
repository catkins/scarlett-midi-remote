import SwiftUI
import Combine
import FocusriteControlKit
import MidiKit

struct DeviceView: View {
    @StateObject private var viewModel = DeviceViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.midiLearnEnabled {
                Text(appState.pendingLearnTargetId == nil
                     ? "MIDI Learn — click a fader, mute, or solo, then move a knob."
                     : "Move a knob to map \(appState.pendingLearnName).")
                    .font(.caption)
                    .foregroundStyle(appState.highlightSwatch.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MixerPanel(
                state: viewModel.displayState(appState: appState),
                masterDb: $viewModel.masterDb,
                onSelectOutput: { id in
                    viewModel.selectedOutputId = id
                    viewModel.outputSelectionChanged()
                },
                onRefresh: { viewModel.requestSnapshot() },
                onMasterEditing: { editing in
                    viewModel.masterSliderChanged(editing: editing)
                },
                onMasterMute: { muted in
                    viewModel.masterMute = muted
                    viewModel.userChangedMasterMute(muted)
                },
                onLearn: { id, name in
                    appState.beginMidiLearn(targetId: id, name: name)
                },
                onStripGain: { strip, db in
                    viewModel.setMixGain(strip: strip, db: db)
                },
                onStripMute: { strip, muted in
                    viewModel.setMixMute(strip: strip, muted: muted)
                },
                onStripSolo: { strip, solo in
                    viewModel.setMixSolo(strip: strip, solo: solo)
                }
            )
            .environmentObject(viewModel.meters)
            .onChange(of: viewModel.masterDb) { _, _ in
                viewModel.masterValueChanged()
            }

            if viewModel.showApprovalHint {
                Text("Approve this app in Focusrite Control → Settings → Remote Devices if faders don’t stick.")
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
    let meters = MeterLevels()

    var selectedOutput: OutputPair? {
        visibleOutputs.first(where: { $0.id == selectedOutputId }) ?? visibleOutputs.first
    }

    private var appState: AppState?
    private var applyingRemote = false
    private var draggingMaster = false
    private var latest = Scarlett18i20Gen2Model()
    private var cancellables = Set<AnyCancellable>()

    func displayState(appState: AppState) -> MixerDisplayState {
        let output = selectedOutput
        let kind = MonitorKind(id: output?.id ?? "", isMonitor: output?.isMonitor ?? false)
        let title = output?.title ?? "Level"
        return MixerDisplayState(
            deviceModel: deviceModel,
            outputs: visibleOutputs,
            selectedOutputId: selectedOutputId,
            masterTitle: title,
            masterDb: masterDb,
            masterMute: masterMute,
            gainRange: gainRange,
            mixRange: mixRange,
            hardware: mixStrips.filter { $0.kind != "playback" },
            playback: mixStrips.filter { $0.kind == "playback" },
            canRefresh: canRefresh,
            pendingLearnId: appState.pendingLearnTargetId,
            mappedIds: Set(appState.mappings.compactMap { $0.binding == nil ? nil : $0.id }),
            masterGainTargetId: MidiTarget.masterGain(for: kind).id,
            masterMuteTargetId: MidiTarget.masterMute(for: kind).id,
            masterMeterIds: [output?.meterParamId].compactMap { id in
                guard let id, !id.isEmpty else { return nil }
                return id
            }
        )
    }

    func bind(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState

        appState.controlClient.devicePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.apply(model: model)
            }
            .store(in: &cancellables)

        appState.controlClient.meterPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] values in
                self?.meters.replace(values)
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
