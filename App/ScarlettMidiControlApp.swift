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
                .frame(minWidth: 360, minHeight: 420)
        }
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
    
    init() {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore
        self.discoveryService = DiscoveryService()
        let client = ControlServerClient()
        client.clientName = settingsStore.clientName
        client.autoReconnect = settingsStore.autoReconnect
        self.controlClient = client
        self.midiManager = MidiManager(settingsStore: settingsStore)
        
        // Reflect connection state for menu bar icon
        _ = controlClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
    }
}

