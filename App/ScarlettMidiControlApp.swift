import SwiftUI
import AppKit
import Combine
import FocusriteControlKit
import MidiKit
import PersistenceKit

@main
struct ScarlettMidiControlApp: App {
    @StateObject private var appState = AppState()

    init() {
        SnapshotSupport.exitAfterRenderingIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
        } label: {
            MenuBarStatusIcon(state: appState.connectionState)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Fader silhouette; a small × when the mixer isn’t connected.
struct MenuBarStatusIcon: View {
    let state: ConnectionState

    var body: some View {
        ZStack {
            Image(systemName: "slider.vertical.3")
            if state.showsDisconnectedMark {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
            }
        }
        .accessibilityLabel(state.showsDisconnectedMark
                            ? "Scarlett MIDI Control, disconnected"
                            : "Scarlett MIDI Control")
    }
}

final class AppState: ObservableObject {
    let discoveryService: DiscoveryServiceProtocol
    let controlClient: ControlServerClient
    let midiManager: MidiManagerProtocol
    let settingsStore: SettingsStoreProtocol

    @Published var connectionState: ConnectionState = .disconnected
    @Published var selectedMidiInputUID: Int32?
    @Published var latestDevice = Scarlett18i20Gen2Model()
    @Published var hiddenOutputIds: Set<String> = []
    @Published var didCustomizeHiddenOutputs = false
    @Published var midiLearnEnabled = false
    @Published var pendingLearnTargetId: String?
    @Published var pendingLearnName = ""
    @Published var mappings: [MidiMappingItem] = []
    @Published var highlightSwatch: HighlightSwatch = .purple
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore
        self.discoveryService = DiscoveryService()
        let client = ControlServerClient()
        client.clientName = settingsStore.clientName
        client.clientKey = settingsStore.clientKey
        client.autoReconnect = settingsStore.autoReconnect
        self.controlClient = client
        let midi = MidiManager(settingsStore: settingsStore)
        self.midiManager = midi
        self.hiddenOutputIds = Set(settingsStore.hiddenOutputIds)
        self.didCustomizeHiddenOutputs = settingsStore.didCustomizeHiddenOutputs
        self.selectedMidiInputUID = settingsStore.selectedMidiInputUID
        let loaded: [MidiMappingItem] = settingsStore.loadMappings() ?? []
        self.mappings = loaded.filter { $0.binding != nil }
        self.highlightSwatch = HighlightSwatch(rawValue: settingsStore.highlightColorId) ?? .purple

        controlClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        controlClient.devicePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.latestDevice = model
            }
            .store(in: &cancellables)

        midi.onMessage = { [weak self] message in
            DispatchQueue.main.async {
                self?.applyMappedMidi(message)
            }
        }
        midi.onLearnedMessage = { [weak self] message in
            DispatchQueue.main.async {
                self?.completeMidiLearn(message)
            }
        }

        discoveryService.discoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] server in
                guard let self, self.settingsStore.autoReconnect else { return }
                switch self.connectionState {
                case .disconnected, .discovered, .discovering, .error:
                    self.controlClient.connect(to: server)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        if let uid = selectedMidiInputUID {
            midi.selectInput(uid: uid)
        }

        if !ProcessInfo.processInfo.arguments.contains("--snapshot") {
            discoveryService.startDiscovery()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func setOutputVisible(_ id: String, visible: Bool) {
        didCustomizeHiddenOutputs = true
        if visible {
            hiddenOutputIds.remove(id)
        } else {
            hiddenOutputIds.insert(id)
        }
        settingsStore.didCustomizeHiddenOutputs = true
        settingsStore.hiddenOutputIds = Array(hiddenOutputIds)
    }

    func setHighlight(_ swatch: HighlightSwatch) {
        highlightSwatch = swatch
        settingsStore.highlightColorId = swatch.rawValue
    }

    func setMidiLearnEnabled(_ enabled: Bool) {
        midiLearnEnabled = enabled
        if !enabled {
            pendingLearnTargetId = nil
            pendingLearnName = ""
        }
        midiManager.setLearningEnabled(enabled)
    }

    func beginMidiLearn(targetId: String, name: String) {
        guard midiLearnEnabled else { return }
        pendingLearnTargetId = targetId
        pendingLearnName = name
        midiManager.setLearningEnabled(true)
    }

    func clearMapping(id: String) {
        mappings.removeAll { $0.id == id }
        settingsStore.saveMappings(mappings)
    }

    func completeMidiLearn(_ message: MidiMessage) {
        guard midiLearnEnabled, let targetId = pendingLearnTargetId else { return }
        guard message.kind == .controlChange || message.kind == .noteOn else { return }
        guard let uid = selectedMidiInputUID ?? settingsStore.selectedMidiInputUID else { return }
        let type: MidiBinding.MessageType = message.kind == .noteOn ? .noteOn : .cc
        let binding = MidiBinding(portUID: uid, channel: message.channel, type: type, number: message.data1)
        if let idx = mappings.firstIndex(where: { $0.id == targetId }) {
            mappings[idx].controlName = pendingLearnName.isEmpty ? mappings[idx].controlName : pendingLearnName
            mappings[idx].binding = binding
        } else {
            mappings.append(MidiMappingItem(id: targetId, controlName: pendingLearnName, binding: binding))
        }
        settingsStore.saveMappings(mappings)
        pendingLearnTargetId = nil
        pendingLearnName = ""
    }

    private func applyMappedMidi(_ message: MidiMessage) {
        guard message.kind == .controlChange || message.kind == .noteOn else { return }
        let outputRange = latestDevice.gainRange
        let mixRange = latestDevice.mixGainRange
        for mapping in mappings {
            guard let binding = mapping.binding, binding.channel == message.channel else { continue }
            let matchesCC = message.kind == .controlChange && binding.type == .cc && binding.number == message.data1
            let matchesNote = message.kind == .noteOn
                && (binding.type == .noteOn || binding.type == .noteOff)
                && binding.number == message.data1
            guard matchesCC || matchesNote else { continue }
            guard let target = MidiTarget.parse(mapping.id) else { continue }
            switch target {
            case .monitorGain:
                controlClient.setMonitorDb(Scarlett18i20Gen2Model.midiToDb(message.data2, range: outputRange))
            case .monitorMute:
                applyFlag(message) { controlClient.setMonitorMute($0) }
            case .outputGain(let id):
                controlClient.setOutputGain(id: id, db: Scarlett18i20Gen2Model.midiToDb(message.data2, range: outputRange))
            case .outputMute(let id):
                applyFlag(message) { controlClient.setOutputMute(id: id, enabled: $0) }
            case .mixGain(let mixId, let slot):
                controlClient.setMixGain(
                    mixId: mixId,
                    slotIndex: slot,
                    db: Scarlett18i20Gen2Model.midiToDb(message.data2, range: mixRange)
                )
            case .mixMute(let mixId, let slot):
                applyFlag(message) { controlClient.setMixMute(mixId: mixId, slotIndex: slot, enabled: $0) }
            case .mixSolo(let mixId, let slot):
                applyFlag(message) { controlClient.setMixSolo(mixId: mixId, slotIndex: slot, enabled: $0) }
            }
        }
    }

    private func applyFlag(_ message: MidiMessage, _ set: (Bool) -> Void) {
        if message.kind == .noteOn {
            set(message.data2 > 0)
        } else {
            set(Scarlett18i20Gen2Model.midiToMute(message.data2))
        }
    }
}
