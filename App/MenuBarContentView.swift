import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeviceView()
            ConsoleHairline()
            ConnectionView()
        }
        .padding(12)
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.highlightSwatch, appState.highlightSwatch)
        .background {
            GlassPanelBackground { visible in
                appState.controlClient.setMeterUpdatesEnabled(visible)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ConsoleTheme.glassEdge, lineWidth: 0.6)
        )
    }
}

/// Native menu-style vibrancy. Retunes any system effect view so we do not stack two frosts.
private struct GlassPanelBackground: NSViewRepresentable {
    var onVisible: (Bool) -> Void

    func makeNSView(context: Context) -> ChromeView {
        let view = ChromeView()
        view.onVisible = onVisible
        return view
    }

    func updateNSView(_ nsView: ChromeView, context: Context) {
        nsView.onVisible = onVisible
        nsView.applyWindowGlass()
    }

    final class ChromeView: NSView {
        var onVisible: ((Bool) -> Void)?
        private let fallback = NSVisualEffectView()
        private var observations: [NSObjectProtocol] = []

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            fallback.material = .menu
            fallback.blendingMode = .behindWindow
            fallback.state = .active
            fallback.autoresizingMask = [.width, .height]
            addSubview(fallback)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            fallback.frame = bounds
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observations.forEach { NotificationCenter.default.removeObserver($0) }
            observations.removeAll()
            applyWindowGlass()
            guard let window else {
                onVisible?(false)
                return
            }
            let center = NotificationCenter.default
            let handler: (Notification) -> Void = { [weak self] _ in
                self?.report()
            }
            observations = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main, using: handler),
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main, using: handler),
                center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main, using: handler)
            ]
            report()
        }

        func applyWindowGlass() {
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.hasShadow = true
            window.appearance = nil

            var sawSystemEffect = false
            func visit(_ view: NSView) {
                view.wantsLayer = true
                if let effect = view as? NSVisualEffectView {
                    effect.material = .menu
                    effect.blendingMode = .behindWindow
                    effect.state = .active
                    if effect !== fallback {
                        sawSystemEffect = true
                    }
                } else if view.layer?.backgroundColor != nil {
                    view.layer?.backgroundColor = NSColor.clear.cgColor
                }
                view.subviews.forEach(visit)
            }
            if let content = window.contentView {
                visit(content)
            }
            fallback.isHidden = sawSystemEffect
        }

        private func report() {
            guard let window else {
                onVisible?(false)
                return
            }
            onVisible?(window.isVisible && window.occlusionState.contains(.visible))
        }

        deinit {
            observations.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}
