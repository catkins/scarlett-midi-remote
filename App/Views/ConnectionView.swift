import SwiftUI
import Combine
import FocusriteControlKit

struct ConnectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConnectionViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(viewModel.state.color)
                    .frame(width: 12, height: 12)
                Text(viewModel.state.description)
                    .font(.headline)
                Spacer()
                Button(action: viewModel.discover) {
                    Label("Discover", systemImage: "dot.radiowaves.left.and.right")
                }
                Button(action: viewModel.connect) {
                    Label("Connect", systemImage: "link")
                }
                .disabled(!viewModel.canConnect)
            }
            if let server = viewModel.discoveredServer {
                Text("Discovered: \(server.host):\(server.port)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No server discovered yet. Ensure Focusrite Control is installed and running.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            viewModel.bind(appState: appState)
        }
    }
}

final class ConnectionViewModel: ObservableObject {
    @Published var state: ConnectionState = .disconnected
    @Published var discoveredServer: DiscoveredServer?
    
    private var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []
    
    var canConnect: Bool { discoveredServer != nil && state == .discovered }
    
    func bind(appState: AppState) {
        self.appState = appState
        appState.discoveryService.discoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] server in
                self?.discoveredServer = server
                self?.state = .discovered
            }
            .store(in: &cancellables)
        
        appState.controlClient.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }
    
    func discover() {
        appState?.discoveryService.startDiscovery()
    }
    
    func connect() {
        guard let server = discoveredServer else { return }
        appState?.controlClient.connect(to: server)
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

