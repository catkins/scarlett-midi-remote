import SwiftUI
import Combine
import FocusriteControlKit
import MidiKit
import PersistenceKit

@main
struct ScarlettMidiControlApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Scarlett MIDI Control") { }
            }
        }
    }
}

final class AppState: ObservableObject {
    // Singletons for dependency injection; simple for MVP
    let discoveryService: DiscoveryServiceProtocol
    let controlClient: ControlServerClientProtocol
    let midiManager: MidiManagerProtocol
    let settingsStore: SettingsStoreProtocol
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var selectedMidiInputName: String?
    
    init() {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore
        self.discoveryService = DiscoveryService()
        self.controlClient = ControlServerClient()
        self.midiManager = MidiManager(settingsStore: settingsStore)
    }
}

