import SwiftUI
import MidiKit
import PersistenceKit

struct MidiMappingView: View {
    @StateObject private var viewModel = MidiMappingViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
                Picker("MIDI Input", selection: $viewModel.selectedInputUID) {
                    Text("None").tag(Optional<Int32>.none)
                    ForEach(viewModel.availableInputs, id: \.uid) { info in
                        Text(info.name).tag(Optional(info.uid))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Button {
                    viewModel.refreshInputs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh MIDI inputs")
            }
            .onChange(of: viewModel.selectedInputUID) { _, newValue in
                viewModel.selectInput(uid: newValue)
            }
            
            if let armedId = viewModel.armedControlId {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Move a knob to map \(displayName(for: armedId))")
                    Spacer()
                    Button("Cancel") { viewModel.cancelLearning() }
                        .controlSize(.small)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            VStack(spacing: 6) {
                ForEach(viewModel.mappings, id: \.id) { mapping in
                    MappingRow(
                        mapping: mapping,
                        isArmed: viewModel.armedControlId == mapping.id,
                        onLearn: { viewModel.armLearn(for: mapping.id) },
                        onClear: { viewModel.clear(mapping: mapping) }
                    )
                }
            }
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
    
    private func displayName(for controlId: String) -> String {
        viewModel.mappings.first(where: { $0.id == controlId })?.controlName ?? controlId
    }
}

private struct MappingRow: View {
    let mapping: MidiMappingItem
    let isArmed: Bool
    let onLearn: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Text(mapping.controlName)
                .font(.subheadline)
                .frame(width: 84, alignment: .leading)
            
            Text(mapping.compactBindingDescription)
                .font(.caption)
                .foregroundStyle(mapping.binding == nil ? .tertiary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isArmed {
                Text("Listening")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                Button("Learn") { onLearn() }
                    .controlSize(.small)
            }
            
            Button {
                onClear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(mapping.binding == nil)
            .opacity(mapping.binding == nil ? 0.35 : 1)
            .help("Clear mapping")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isArmed ? Color.orange.opacity(0.10) : Color.primary.opacity(0.04))
        )
    }
}

final class MidiMappingViewModel: ObservableObject {
    @Published var availableInputs: [MidiInputInfo] = []
    @Published var selectedInputUID: Int32?
    @Published var armedControlId: String?
    @Published var mappings: [MidiMappingItem] = MidiMappingItem.defaultItems
    
    private var midiManager: MidiManagerProtocol?
    private var settings: SettingsStoreProtocol?
    
    func bind(appState: AppState) {
        midiManager = appState.midiManager
        settings = appState.settingsStore
        refreshInputs()
        selectedInputUID = settings?.selectedMidiInputUID
        if let uid = selectedInputUID {
            midiManager?.selectInput(uid: uid)
        }
        midiManager?.onLearnedMessage = { [weak self] message in
            guard let self else { return }
            // Prefer Control Change for MVP
            guard message.kind == .controlChange else { return }
            guard let controlId = self.armedControlId,
                  let uid = self.selectedInputUID,
                  let idx = self.mappings.firstIndex(where: { $0.id == controlId }) else { return }
            self.mappings[idx].binding = MidiBinding(portUID: uid,
                                                     channel: message.channel,
                                                     type: .cc,
                                                     number: message.data1)
            self.settings?.saveMappings(self.mappings)
            self.armedControlId = nil
            self.midiManager?.setLearningEnabled(false)
        }
        self.mappings = settings?.loadMappings() ?? MidiMappingItem.defaultItems
    }
    
    func armLearn(for controlId: String) {
        armedControlId = controlId
        midiManager?.setLearningEnabled(true)
    }
    
    func cancelLearning() {
        armedControlId = nil
        midiManager?.setLearningEnabled(false)
    }
    
    func refreshInputs() {
        availableInputs = midiManager?.availableInputs() ?? []
    }
    
    func selectInput(uid: Int32?) {
        guard let uid else { return }
        midiManager?.selectInput(uid: uid)
        settings?.selectedMidiInputUID = uid
    }
    
    func clear(mapping: MidiMappingItem) {
        guard let idx = mappings.firstIndex(where: { $0.id == mapping.id }) else { return }
        mappings[idx].binding = nil
        settings?.saveMappings(mappings)
    }
}

struct MidiBinding: Identifiable, Codable, Equatable {
    enum MessageType: String, Codable { case cc, noteOn, noteOff, pitchBend }
    var id: String { "\(portUID)-\(channel)-\(type)-\(number)" }
    let portUID: Int32
    let channel: UInt8
    let type: MessageType
    let number: UInt8
}

struct MidiMappingItem: Identifiable, Codable {
    let id: String
    let controlName: String
    var binding: MidiBinding?
    
    var bindingDescription: String {
        compactBindingDescription
    }
    
    var compactBindingDescription: String {
        guard let b = binding else { return "Unmapped" }
        switch b.type {
        case .cc: return "CC \(b.number) · Ch \(b.channel + 1)"
        case .noteOn: return "Note On \(b.number) · Ch \(b.channel + 1)"
        case .noteOff: return "Note Off \(b.number) · Ch \(b.channel + 1)"
        case .pitchBend: return "Pitch Bend · Ch \(b.channel + 1)"
        }
    }
    
    static var defaultItems: [MidiMappingItem] = [
        MidiMappingItem(id: "monitor", controlName: "Monitor", binding: nil),
        MidiMappingItem(id: "mute", controlName: "Mute", binding: nil)
    ]
}
