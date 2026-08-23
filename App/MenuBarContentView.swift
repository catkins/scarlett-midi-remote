import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("clientName") private var clientName: String = "Scarlett MIDI Control"
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConnectionView()
            
            Divider()
            
            PanelSection(title: "Mixer", systemImage: "slider.horizontal.3") {
                DeviceView()
            }
            
            Divider()
            
            PanelSection(title: "MIDI Mapping", systemImage: "pianokeys") {
                MidiMappingView()
            }
            
            Divider()
            
            PanelSection(title: "Settings", systemImage: "gearshape") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Client name", text: $clientName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: clientName) { _, newValue in
                                appState.settingsStore.clientName = newValue
                                appState.controlClient.clientName = newValue
                            }
                    }
                    Toggle("Auto-reconnect", isOn: $autoReconnect)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: autoReconnect) { _, newValue in
                            appState.settingsStore.autoReconnect = newValue
                            appState.controlClient.autoReconnect = newValue
                        }

                    let pairs = appState.latestDevice.outputPairs()
                    if !pairs.isEmpty {
                        Text("Visible outputs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(pairs) { pair in
                            let shown = appState.didCustomizeHiddenOutputs
                                ? !appState.hiddenOutputIds.contains(pair.id)
                                : pair.kind == "analogue"
                            Toggle(pair.title, isOn: Binding(
                                get: { shown },
                                set: { appState.setOutputVisible(pair.id, visible: $0) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}
