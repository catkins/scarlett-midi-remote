import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection")) {
                    ConnectionView()
                }
                Section(header: Text("Device")) {
                    DeviceView()
                }
                Section(header: Text("MIDI Mapping")) {
                    MidiMappingView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Scarlett MIDI Control")
        }
        .frame(minWidth: 920, minHeight: 600)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}

