import SwiftUI
import Combine
import FocusriteControlKit

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.highlightSwatch) private var swatch
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var showSettings = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(viewModel.state.color)
                .accessibilityHidden(true)

            Text(viewModel.state.shortTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(serverSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(serverSummary)

            Spacer(minLength: 6)

            if viewModel.showDisconnect {
                Button("Disconnect", action: viewModel.disconnect)
                    .controlSize(.mini)
            } else {
                Button("Connect", action: viewModel.connect)
                    .controlSize(.mini)
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canConnect)
                    .tint(swatch.color)
            }

            Button {
                appState.setMidiLearnEnabled(!appState.midiLearnEnabled)
            } label: {
                Image(systemName: "pianokeys")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appState.midiLearnEnabled ? swatch.color : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(appState.midiLearnEnabled
                  ? "MIDI Learn on — click a control, then move a knob"
                  : "MIDI Learn")

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showSettings ? swatch.color : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .popover(isPresented: $showSettings, arrowEdge: .top) {
                SettingsPopover()
                    .environmentObject(appState)
                    .environment(\.highlightSwatch, appState.highlightSwatch)
            }

            Button("Quit") {
                appState.quit()
            }
            .controlSize(.mini)
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }

    private var serverSummary: String {
        if let server = viewModel.discoveredServer {
            return "\(server.host):\(server.port)"
        }
        return "Waiting for Focusrite Control"
    }
}

final class ConnectionViewModel: ObservableObject {
    @Published var state: ConnectionState = .disconnected
    @Published var discoveredServer: DiscoveredServer?

    private var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []

    var canConnect: Bool {
        discoveredServer != nil && !showDisconnect
    }

    var showDisconnect: Bool {
        switch state {
        case .connecting, .awaitingApproval, .connected: return true
        default: return false
        }
    }

    func bind(appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState
        appState.discoveryService.discoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] server in
                guard let self else { return }
                self.discoveredServer = server
                if case .disconnected = self.state { self.state = .discovered }
                switch self.state {
                case .disconnected, .discovered, .discovering, .error:
                    if appState.settingsStore.autoReconnect {
                        appState.controlClient.connect(to: server)
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)

        appState.controlClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)

        discover()
    }

    func discover() {
        if case .disconnected = state { state = .discovering }
        appState?.discoveryService.startDiscovery()
    }

    func connect() {
        guard let server = discoveredServer else { return }
        appState?.controlClient.connect(to: server)
    }

    func disconnect() {
        appState?.controlClient.disconnect()
    }
}

extension ConnectionState {
    var shortTitle: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Discovering"
        case .discovered: return "Ready"
        case .connecting: return "Connecting"
        case .awaitingApproval: return "Approve in Focusrite Control"
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }

    var description: String { shortTitle }

    var color: Color {
        switch self {
        case .disconnected, .error: return .red
        case .discovering, .connecting, .awaitingApproval: return .yellow
        case .discovered: return .blue
        case .connected: return .green
        }
    }

    var showsDisconnectedMark: Bool {
        switch self {
        case .connected, .connecting, .awaitingApproval: return false
        default: return true
        }
    }
}
