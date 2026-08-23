import SwiftUI
import MidiKit
import PersistenceKit

struct MidiMappingView: View {
    @StateObject private var viewModel = MidiMappingViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("MIDI Input", selection: $viewModel.selectedInputName) {
                    ForEach(viewModel.availableInputs, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .frame(maxWidth: 320)
                Button("Refresh") { viewModel.refreshInputs() }
                Spacer()
                Toggle("MIDI Learn", isOn: $viewModel.isLearning)
            }
            .onChange(of: viewModel.selectedInputName) { _, newValue in
                viewModel.selectInput(named: newValue)
            }
            
            List {
                ForEach(viewModel.mappings, id: \.id) { mapping in
                    HStack {
                        Text(mapping.controlName)
                        Spacer()
                        Text(mapping.midiDescription)
                            .foregroundColor(.secondary)
                        Button("Clear") {
                            viewModel.clear(mapping: mapping)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
}

final class MidiMappingViewModel: ObservableObject {
    @Published var availableInputs: [String] = []
    @Published var selectedInputName: String?
    @Published var isLearning: Bool = false {
        didSet { midiManager?.setLearningEnabled(isLearning) }
    }
    @Published var mappings: [MidiMappingItem] = MidiMappingItem.defaultItems
    
    private var midiManager: MidiManagerProtocol?
    private var settings: SettingsStoreProtocol?
    
    func bind(appState: AppState) {
        midiManager = appState.midiManager
        settings = appState.settingsStore
        refreshInputs()
        selectedInputName = settings?.selectedMidiInputName
        if let name = selectedInputName {
            midiManager?.selectInput(named: name)
        }
        midiManager?.onLearnedMessage = { [weak self] message in
            guard let self else { return }
            // For MVP: always map to the first unmapped item
            if let idx = self.mappings.firstIndex(where: { $0.midiMessage == nil }) {
                self.mappings[idx].midiMessage = message
                self.settings?.saveMappings(self.mappings)
            }
        }
        self.mappings = settings?.loadMappings() ?? MidiMappingItem.defaultItems
    }
    
    func refreshInputs() {
        availableInputs = midiManager?.availableInputNames() ?? []
    }
    
    func selectInput(named name: String?) {
        guard let name else { return }
        midiManager?.selectInput(named: name)
        settings?.selectedMidiInputName = name
    }
    
    func clear(mapping: MidiMappingItem) {
        guard let idx = mappings.firstIndex(where: { $0.id == mapping.id }) else { return }
        mappings[idx].midiMessage = nil
        settings?.saveMappings(mappings)
    }
}

struct MidiMappingItem: Identifiable, Codable {
    let id: String
    let controlName: String
    var midiMessage: MidiMessage?
    
    var midiDescription: String {
        if let msg = midiMessage {
            return msg.shortDescription
        }
        return "Unmapped"
    }
    
    static var defaultItems: [MidiMappingItem] = [
        MidiMappingItem(id: "monitorL", controlName: "Monitor L", midiMessage: nil),
        MidiMappingItem(id: "monitorR", controlName: "Monitor R", midiMessage: nil),
        MidiMappingItem(id: "mute", controlName: "Mute", midiMessage: nil)
    ]
}

