import SwiftUI
import Combine
import FocusriteControlKit
import MidiKit
import PersistenceKit

@main
struct ScarlettMidiControlApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("Scarlett MIDI Control", systemImage: menuBarIconName) {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
    
    private var menuBarIconName: String {
        switch appState.connectionState {
        case .connected: return "dot.radiowaves.left.and.right"
        case .awaitingApproval: return "questionmark.diamond"
        case .connecting, .discovering, .discovered: return "bolt.badge.clock"
        case .error: return "exclamationmark.triangle"
        case .disconnected: return "bolt.slash"
        }
    }
}

final class AppState: ObservableObject {
    // Singletons for dependency injection; simple for MVP
    let discoveryService: DiscoveryServiceProtocol
    let controlClient: ControlServerClient
    let midiManager: MidiManagerProtocol
    let settingsStore: SettingsStoreProtocol
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var selectedMidiInputUID: Int32?
    @Published var latestDevice = Scarlett18i20Gen2Model()
    @Published var hiddenOutputIds: Set<String> = []
    @Published var didCustomizeHiddenOutputs = false
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
        
        discoveryService.startDiscovery()
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

    private func applyMappedMidi(_ message: MidiMessage) {
        guard message.kind == .controlChange || message.kind == .noteOn else { return }
        guard let mappings: [MidiMappingItem] = settingsStore.loadMappings() else { return }
        let range = latestDevice.gainRange
        for mapping in mappings {
            guard let binding = mapping.binding, binding.channel == message.channel else { continue }
            let matchesCC = message.kind == .controlChange && binding.type == .cc && binding.number == message.data1
            let matchesNote = message.kind == .noteOn && (binding.type == .noteOn || binding.type == .noteOff) && binding.number == message.data1
            guard matchesCC || matchesNote else { continue }
            switch mapping.id {
            case "monitorL", "monitorR", "monitor":
                controlClient.setMonitorDb(Scarlett18i20Gen2Model.midiToDb(message.data2, range: range))
            case "mute":
                if message.kind == .noteOn {
                    controlClient.setMonitorMute(message.data2 > 0)
                } else {
                    controlClient.setMonitorMute(Scarlett18i20Gen2Model.midiToMute(message.data2))
                }
            default:
                break
            }
        }
    }
}

