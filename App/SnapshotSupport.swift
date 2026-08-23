import AppKit
import SwiftUI
import FocusriteControlKit

enum SnapshotSupport {
    @discardableResult
    static func exitAfterRenderingIfRequested() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--snapshot"), args.indices.contains(index + 1) else {
            return false
        }
        let url = URL(fileURLWithPath: args[index + 1])
        do {
            try renderBlocking(to: url)
            FileHandle.standardError.write(Data("Wrote snapshot \(url.path)\n".utf8))
            Darwin.exit(0)
        } catch {
            FileHandle.standardError.write(Data("Snapshot failed: \(error)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func renderBlocking(to url: URL) throws {
        var captured: Error?
        let run = {
            do {
                try MainActor.assumeIsolated {
                    try render(to: url)
                }
            } catch {
                captured = error
            }
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.sync(execute: run)
        }
        if let captured { throw captured }
    }

    @MainActor
    static func render(to url: URL) throws {
        _ = NSApplication.shared
        let content = MixerSnapshotView()
            .frame(width: 390)
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(ConsoleTheme.glassEdge, lineWidth: 0.6)
            )
            .environment(\.highlightSwatch, .purple)
            .environmentObject(snapshotMeters)

        let host = NSHostingView(rootView: content)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        let fitted = host.fittingSize
        let size = NSSize(width: max(414, fitted.width), height: max(200, fitted.height))
        host.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.appearance = nil
        window.alphaValue = 1
        window.setFrameOrigin(NSPoint(x: -4000, y: -4000))

        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true

        let backdrop = NSView(frame: root.bounds)
        backdrop.wantsLayer = true
        backdrop.autoresizingMask = [.width, .height]
        let gradient = CAGradientLayer()
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        gradient.colors = dark
            ? [
                NSColor(calibratedRed: 0.22, green: 0.48, blue: 0.92, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1).cgColor
            ]
            : [
                NSColor(calibratedRed: 0.62, green: 0.76, blue: 0.96, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.92, alpha: 1).cgColor
            ]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.frame = backdrop.bounds
        backdrop.layer = gradient

        let glass = NSVisualEffectView(frame: root.bounds)
        glass.material = .menu
        glass.blendingMode = .withinWindow
        glass.state = .active
        glass.autoresizingMask = [.width, .height]
        host.autoresizingMask = [.width, .height]
        glass.addSubview(host)

        root.addSubview(backdrop)
        root.addSubview(glass)
        window.contentView = root
        window.orderFrontRegardless()
        root.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        guard let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
            throw NSError(domain: "SnapshotSupport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not cache glass snapshot"])
        }
        root.cacheDisplay(in: root.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SnapshotSupport", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
        }
        window.orderOut(nil)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
    }

    private static var snapshotMeters: MeterLevels {
        let meters = MeterLevels()
        meters.replace([
            "mMaster": -18,
            "m1": -28,
            "m2": -9,
            "m3": -14,
            "m4": -6,
            "m5": -22,
            "m6": -11
        ])
        return meters
    }
}

private struct MixerSnapshotView: View {
    @State private var masterDb: Double = -47.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MixerPanel(
                state: fixtureState,
                masterDb: $masterDb,
                onSelectOutput: { _ in },
                onRefresh: {},
                onMasterEditing: { _ in },
                onMasterMute: { _ in },
                onLearn: { _, _ in },
                onStripGain: { _, _ in },
                onStripMute: { _, _ in },
                onStripSolo: { _, _ in }
            )
            ConsoleHairline()
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("Connected").font(.subheadline.weight(.semibold))
                Text("127.0.0.1:49152")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Disconnect").font(.caption)
                Image(systemName: "pianokeys").foregroundStyle(.secondary)
                Image(systemName: "gearshape").foregroundStyle(.secondary)
                Text("Quit").font(.caption)
            }
        }
    }

    private var fixtureState: MixerDisplayState {
        MixerDisplayState(
            deviceModel: "Scarlett 18i20 (2nd Gen)",
            outputs: [
                OutputPair(id: "1", title: "Monitors", kind: "analogue", leftId: "1", isMonitor: true, assignedMixId: "54", gainDb: -47.5),
                OutputPair(id: "2", title: "BigSky Send", kind: "analogue", leftId: "2", isMonitor: false, assignedMixId: "202"),
                OutputPair(id: "3", title: "Line Outputs 5-6", kind: "analogue", leftId: "3", isMonitor: false, assignedMixId: "350"),
                OutputPair(id: "4", title: "Headphones", kind: "analogue", leftId: "4", isMonitor: false, assignedMixId: "498")
            ],
            selectedOutputId: "1",
            masterTitle: "Monitors",
            masterDb: -47.5,
            masterMute: false,
            gainRange: -80...10,
            mixRange: -80...6,
            hardware: [
                VisibleMixStrip(id: "a", mixId: "54", slotIndex: 0, title: "Bigsky Ret", kind: "analogue", stereo: true, gainDb: 0, muted: true, solo: false, meterParamId: "m1"),
                VisibleMixStrip(id: "b", mixId: "54", slotIndex: 2, title: "Prophet", kind: "analogue", stereo: true, gainDb: 0, muted: false, solo: false, meterParamId: "m2"),
                VisibleMixStrip(id: "c", mixId: "54", slotIndex: 4, title: "Sub37", kind: "analogue", stereo: true, gainDb: 0, muted: false, solo: false, meterParamId: "m3"),
                VisibleMixStrip(id: "d", mixId: "54", slotIndex: 6, title: "Analogue 1", kind: "analogue", stereo: false, gainDb: 6, muted: false, solo: false, meterParamId: "m4"),
                VisibleMixStrip(id: "e", mixId: "54", slotIndex: 7, title: "Røde NT1", kind: "analogue", stereo: false, gainDb: 6, muted: false, solo: false, meterParamId: "m5")
            ],
            playback: [
                VisibleMixStrip(id: "p", mixId: "54", slotIndex: 16, title: "Playback 1-2", kind: "playback", stereo: true, gainDb: 0, muted: false, solo: false, meterParamId: "m6")
            ],
            canRefresh: true,
            pendingLearnId: nil,
            mappedIds: ["monitor"],
            masterGainTargetId: "monitor",
            masterMuteTargetId: "mute",
            masterMeterIds: ["mMaster"]
        )
    }
}
