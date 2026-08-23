import SwiftUI
import Combine
import FocusriteControlKit

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConnectionViewModel()
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(viewModel.state.color)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.state.description)
                    .font(.headline)
                Text(serverSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            if viewModel.showDisconnect {
                Button("Disconnect", action: viewModel.disconnect)
                    .controlSize(.small)
            } else {
                Button("Discover", action: viewModel.discover)
                    .controlSize(.small)
                Button("Connect", action: viewModel.connect)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canConnect)
            }
        }
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
    
    private var serverSummary: String {
        if let server = viewModel.discoveredServer {
            return "\(server.host):\(server.port)"
        }
        return "Focusrite Control must be running to discover a server."
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
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Discovering…"
        case .discovered: return "Discovered — awaiting connect"
        case .connecting: return "Connecting…"
        case .awaitingApproval: return "Awaiting approval in Focusrite Control"
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected, .error: return .red
        case .discovering, .connecting, .awaitingApproval: return .yellow
        case .discovered: return .blue
        case .connected: return .green
        }
    }
}
