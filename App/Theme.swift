import SwiftUI
import FocusriteControlKit

/// Dracula palette accents. Default highlight is purple (`#bd93f9`).
enum HighlightSwatch: String, CaseIterable, Identifiable {
    case purple
    case pink
    case cyan
    case green
    case orange
    case red
    case yellow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        case .yellow: return "Yellow"
        }
    }

    var color: Color {
        switch self {
        case .purple: return Color(red: 0.741, green: 0.576, blue: 0.976) // #bd93f9
        case .pink: return Color(red: 1.0, green: 0.475, blue: 0.776)     // #ff79c6
        case .cyan: return Color(red: 0.545, green: 0.914, blue: 0.992)   // #8be9fd
        case .green: return Color(red: 0.314, green: 0.980, blue: 0.482)  // #50fa7b
        case .orange: return Color(red: 1.0, green: 0.722, blue: 0.424)   // #ffb86c
        case .red: return Color(red: 1.0, green: 0.333, blue: 0.333)      // #ff5555
        case .yellow: return Color(red: 0.945, green: 0.980, blue: 0.549) // #f1fa8e
        }
    }

    /// Text/icon color on a filled chip of this swatch.
    var onColor: Color {
        switch self {
        case .red: return .white
        default: return Color(red: 0.157, green: 0.165, blue: 0.212) // #282a36
        }
    }

    static let `default`: HighlightSwatch = .purple
}

private struct HighlightSwatchKey: EnvironmentKey {
    static let defaultValue = HighlightSwatch.default
}

extension EnvironmentValues {
    var highlightSwatch: HighlightSwatch {
        get { self[HighlightSwatchKey.self] }
        set { self[HighlightSwatchKey.self] = newValue }
    }
}

enum ConsoleTheme {
    static let well = Color.primary.opacity(0.06)
    static let wellStroke = Color.primary.opacity(0.14)
    static let glassEdge = Color.primary.opacity(0.22)
    static let mute = Color(red: 0.85, green: 0.22, blue: 0.20)
    static let solo = Color(red: 0.93, green: 0.72, blue: 0.16)

    static var section: Font { .system(size: 10, weight: .bold, design: .rounded) }
    static var chip: Font { .system(size: 11, weight: .semibold) }
    static var strip: Font { .system(size: 11, weight: .medium) }
}

struct ConsoleHairline: View {
    var body: some View {
        Rectangle()
            .fill(ConsoleTheme.wellStroke)
            .frame(height: 1)
    }
}

struct ConsoleSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(ConsoleTheme.section)
            .tracking(0.9)
            .foregroundStyle(.secondary)
    }
}

struct ConsoleFlag: View {
    let letter: String
    var active: Bool
    var activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(active ? Color.white : Color.secondary)
                .frame(width: 18, height: 18)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(active ? AnyShapeStyle(activeColor) : AnyShapeStyle(.ultraThinMaterial))
                }
        }
        .buttonStyle(.plain)
    }
}

struct ConsoleFader: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var muted: Bool = false
    var unity: Double = 0
    var armed: Bool = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    @Environment(\.highlightSwatch) private var swatch
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let t = span == 0 ? 0 : CGFloat((value - range.lowerBound) / span)
            let width = max(6, geo.size.width * t)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(muted ? Color.secondary.opacity(0.28) : swatch.color.opacity(0.7))
                    .frame(width: width)
                Circle()
                    .fill(muted ? Color.secondary.opacity(0.55) : Color(nsColor: .textBackgroundColor))
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(muted ? 0.08 : 0.25), radius: 1, y: 0.5)
                    .offset(x: min(max(0, geo.size.width * t - 5.5), max(0, geo.size.width - 11)))
            }
            .frame(height: 11)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(armed ? swatch.color : Color.clear, lineWidth: 1.5)
                    .padding(.vertical, 1)
            )
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { drag in
                        if !dragging {
                            dragging = true
                            onEditingChanged(true)
                        }
                        let x = min(max(0, drag.location.x), geo.size.width)
                        let next = range.lowerBound + Double(x / geo.size.width) * span
                        value = (next * 2).rounded() / 2
                    }
                    .onEnded { _ in
                        dragging = false
                        onEditingChanged(false)
                    }
            )
            .onTapGesture(count: 2) {
                resetToUnity()
            }
            .help("Double-click the handle for 0 dB")
            .animation(.easeOut(duration: 0.12), value: muted)
        }
        .frame(height: 18)
        .accessibilityValue(Text(String(format: "%.1f dB", value)))
        .accessibilityAction(named: "Reset to unity") { resetToUnity() }
    }

    private func resetToUnity() {
        value = min(max(unity, range.lowerBound), range.upperBound)
        onEditingChanged(true)
        onEditingChanged(false)
    }
}

/// Live dBFS levels, updated on a throttle. Meters observe this so the mixer chrome does not rebuild.
final class MeterLevels: ObservableObject {
    static let silence = -128.0
    /// Matches the control-server meter flush so bars ease between samples instead of jumping.
    static let flushInterval: TimeInterval = 0.125
    @Published private(set) var values: [String: Double] = [:]

    func replace(_ next: [String: Double]) {
        guard next != values else { return }
        values = next
    }

    func peak(_ ids: [String]) -> Double {
        var best = Self.silence
        for id in ids where !id.isEmpty {
            if let db = values[id], db > best {
                best = db
            }
        }
        return best
    }
}

struct ConsoleMeter: View {
    var ids: [String]
    var muted: Bool = false
    @EnvironmentObject private var meters: MeterLevels
    @Environment(\.highlightSwatch) private var swatch
    @State private var displayedFill: CGFloat = 0
    @State private var hasAppeared = false

    private var db: Double { meters.peak(ids) }

    var body: some View {
        let target = CGFloat(MixerLayout.meterFill(db: db))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(0, geo.size.width * displayedFill))
            }
        }
        .frame(height: 3)
        .opacity(muted ? 0.35 : 0.8)
        .onAppear {
            displayedFill = target
            hasAppeared = true
        }
        .onChange(of: target) { _, next in
            guard hasAppeared else { return }
            withAnimation(.linear(duration: MeterLevels.flushInterval)) {
                displayedFill = next
            }
        }
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        if muted { return Color.secondary.opacity(0.45) }
        if db > -1 { return swatch.color.opacity(0.95) }
        return swatch.color.opacity(0.5)
    }
}
