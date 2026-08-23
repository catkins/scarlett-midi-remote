import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("clientName") private var clientName: String = "Scarlett MIDI Control"
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Connection
                GroupBox(label: Label("Connection", systemImage: "link")) {
                    ConnectionView()
                    HStack {
                        Text("Status: \(appState.connectionState.description)")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                // Device Primary Controls
                GroupBox(label: Label("Primary Controls", systemImage: "speaker.wave.2")) {
                    DeviceView()
                }
                
                // MIDI Mapping
                GroupBox(label: Label("MIDI Mapping", systemImage: "pianokeys")) {
                    MidiMappingView()
                }
                
                // Settings (lightweight)
                GroupBox(label: Label("Settings", systemImage: "gearshape")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Client name", text: $clientName)
                            .onChange(of: clientName) { _, newValue in
                                appState.settingsStore.clientName = newValue
                                appState.controlClient.clientName = newValue
                            }
                        Toggle("Auto-reconnect", isOn: $autoReconnect)
                            .onChange(of: autoReconnect) { _, newValue in
                                appState.settingsStore.autoReconnect = newValue
                                appState.controlClient.autoReconnect = newValue
                            }
                        Button("Open Full Panel (coming soon)") { }
                            .disabled(true)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 420)
    }
}

