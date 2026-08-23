import SwiftUI
import FocusriteControlKit

struct DeviceView: View {
    @StateObject private var viewModel = DeviceViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scarlett 18i20 (2nd Gen)")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.requestSnapshot) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!viewModel.canRefresh)
            }
            HStack(spacing: 24) {
                VolumeFader(value: $viewModel.monitorLeftDb, title: "Monitor L")
                VolumeFader(value: $viewModel.monitorRightDb, title: "Monitor R")
            }
            .frame(height: 220)
            Toggle("Mute", isOn: $viewModel.monitorMute)
                .toggleStyle(.switch)
                .onChange(of: viewModel.monitorMute) { _, newValue in
                    viewModel.setMute(newValue)
                }
            Text("Note: Monitor controls are placeholders until the protocol is verified live.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
}

struct VolumeFader: View {
    @Binding var value: Double // dB
    let title: String
    
    var body: some View {
        VStack {
            Slider(value: $value, in: -80...10, step: 0.5)
                .rotationEffect(.degrees(-90))
                .frame(height: 180)
            Text(title)
                .font(.subheadline)
            Text(String(format: "%.1f dB", value))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120)
    }
}

final class DeviceViewModel: ObservableObject {
    @Published var monitorLeftDb: Double = -10
    @Published var monitorRightDb: Double = -10
    @Published var monitorMute: Bool = false
    
    private var appState: AppState?
    
    var canRefresh: Bool { true }
    
    func bind(appState: AppState) {
        self.appState = appState
        // TODO: Bind to device model updates when protocol verified
    }
    
    func requestSnapshot() {
        appState?.controlClient.requestDeviceSnapshot()
    }
    
    func setMute(_ enabled: Bool) {
        appState?.controlClient.setMonitorMute(enabled)
    }
}

