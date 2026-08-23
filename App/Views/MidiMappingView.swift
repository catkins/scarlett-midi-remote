import SwiftUI
import MidiKit
import PersistenceKit

struct MidiMappingView: View {
    @StateObject private var viewModel = MidiMappingViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("MIDI Input", selection: $viewModel.selectedInputUID) {
                    Text("None").tag(Optional<Int32>.none)
                    ForEach(viewModel.availableInputs, id: \.uid) { info in
                        Text(info.name).tag(Optional(info.uid))
                    }
                }
                .frame(maxWidth: 280)
                Button("Refresh") { viewModel.refreshInputs() }
                Spacer()
                if let armedId = viewModel.armedControlId {
                    Text("Learning \(armedId)…").foregroundColor(.orange)
                    Button("Cancel") { viewModel.cancelLearning() }
                }
            }
            .onChange(of: viewModel.selectedInputUID) { _, newValue in
                viewModel.selectInput(uid: newValue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.mappings, id: \.id) { mapping in
                    MappingRow(mapping: mapping,
                               isArmed: viewModel.armedControlId == mapping.id,
                               onLearn: { viewModel.armLearn(for: mapping.id) },
                               onClear: { viewModel.clear(mapping: mapping) })
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
}

private struct MappingRow: View {
    let mapping: MidiMappingItem
    let isArmed: Bool
    let onLearn: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Text(mapping.controlName)
            Spacer()
            Text(mapping.bindingDescription)
                .foregroundColor(.secondary)
            if isArmed {
                Text("Learning…").foregroundColor(.orange)
            } else {
                Button("Learn") { onLearn() }
            }
            Button("Clear") { onClear() }
        }
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
        if let b = binding {
            switch b.type {
            case .cc: return "Port \(b.portUID) CC ch\(b.channel+1) #\(b.number)"
            case .noteOn: return "Port \(b.portUID) NoteOn ch\(b.channel+1) #\(b.number)"
            case .noteOff: return "Port \(b.portUID) NoteOff ch\(b.channel+1) #\(b.number)"
            case .pitchBend: return "Port \(b.portUID) PitchBend ch\(b.channel+1)"
            }
        }
        return "Unmapped"
    }
    
    static var defaultItems: [MidiMappingItem] = [
        MidiMappingItem(id: "monitorL", controlName: "Monitor L", binding: nil),
        MidiMappingItem(id: "monitorR", controlName: "Monitor R", binding: nil),
        MidiMappingItem(id: "mute", controlName: "Mute", binding: nil)
    ]
}

