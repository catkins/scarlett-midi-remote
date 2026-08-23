import SwiftUI
import MidiKit

struct SettingsPopover: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("clientName") private var clientName: String = "Scarlett MIDI Control"
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    @State private var midiInputs: [MidiInputInfo] = []
    @State private var selectedInputUID: Int32?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConsoleSectionLabel(title: "Highlight")
            HStack(spacing: 8) {
                ForEach(HighlightSwatch.allCases) { swatch in
                    Button {
                        appState.setHighlight(swatch)
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        appState.highlightSwatch == swatch ? Color.primary : Color.primary.opacity(0.2),
                                        lineWidth: appState.highlightSwatch == swatch ? 2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(swatch.name)
                }
            }
            Text("\(appState.highlightSwatch.name) · Dracula")
                .font(.caption)
                .foregroundStyle(.secondary)

            ConsoleSectionLabel(title: "MIDI")
            HStack(spacing: 6) {
                Picker("MIDI Input", selection: $selectedInputUID) {
                    Text("None").tag(Optional<Int32>.none)
                    ForEach(midiInputs, id: \.uid) { info in
                        Text(info.name).tag(Optional(info.uid))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Button {
                    midiInputs = appState.midiManager.availableInputs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh MIDI inputs")
            }
            .onChange(of: selectedInputUID) { _, uid in
                if let uid {
                    appState.midiManager.selectInput(uid: uid)
                    appState.settingsStore.selectedMidiInputUID = uid
                    appState.selectedMidiInputUID = uid
                }
            }

            Toggle("MIDI Learn", isOn: Binding(
                get: { appState.midiLearnEnabled },
                set: { appState.setMidiLearnEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(appState.highlightSwatch.color)

            Text("Click a fader, mute, or solo in the mixer, then move a knob. Masters are per output; mix strips follow the mix assigned to that output.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let mapped = appState.mappings.filter { $0.binding != nil }
            if mapped.isEmpty {
                Text("No mappings yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(mapped) { item in
                        HStack(spacing: 6) {
                            Text(item.controlName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(item.compactBindingDescription)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                appState.clearMapping(id: item.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Clear mapping")
                        }
                    }
                }
            }

            Divider()

            ConsoleSectionLabel(title: "Client")
            TextField("Client name", text: $clientName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: clientName) { _, newValue in
                    appState.settingsStore.clientName = newValue
                    appState.controlClient.clientName = newValue
                }
            Toggle("Auto-reconnect", isOn: $autoReconnect)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: autoReconnect) { _, newValue in
                    appState.settingsStore.autoReconnect = newValue
                    appState.controlClient.autoReconnect = newValue
                }

            let pairs = appState.latestDevice.outputPairs()
            if !pairs.isEmpty {
                ConsoleSectionLabel(title: "Visible outputs")
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

            Divider()

            Button("Quit Scarlett MIDI Control") {
                appState.quit()
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .onAppear {
            midiInputs = appState.midiManager.availableInputs()
            selectedInputUID = appState.settingsStore.selectedMidiInputUID
        }
    }
}
