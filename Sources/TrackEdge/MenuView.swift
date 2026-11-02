import TrackEdgeCore
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !model.touchAvailable {
                Callout(symbol: "exclamationmark.triangle.fill",
                        text: "This version of macOS does not expose trackpad touches to TrackEdge.")
            } else if !model.trusted {
                Callout(symbol: "lock.fill",
                        text: "TrackEdge needs Accessibility access to change volume and brightness.",
                        action: ("Open Settings", model.openAccessibilitySettings))
            }

            EdgePreview()
                .opacity(prefs.enabled ? 1 : 0.45)

            VStack(spacing: 12) {
                SliderRow(title: "Sensitivity", value: $prefs.sensitivity, range: 0.5...2,
                          label: String(format: "%.1fx", prefs.sensitivity))
                SliderRow(title: "Edge width", value: $prefs.edgeWidth, range: 0.04...0.16,
                          label: "\(Int((prefs.edgeWidth * 100).rounded()))%")
                HStack {
                    Text("Haptics")
                    Spacer()
                    Picker("Haptics", selection: $prefs.haptics) {
                        ForEach(HapticStrength.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 176)
                }
            }

            Divider()

            VStack(spacing: 8) {
                ToggleRow(title: "Media strip", detail: "Swipe the bottom edge to skip", isOn: $prefs.mediaStrip)
                ToggleRow(title: "Quick mute", detail: "Double-tap the top-right corner", isOn: $prefs.quickMute)
                ToggleRow(title: "Precise sliding", detail: "Quarter steps without modifier keys", isOn: $prefs.preciseSliding)
            }

            Divider()

            HStack {
                Button("Settings...") { SettingsWindow.show(model: model) }
                Spacer()
                Button("Quit TrackEdge") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { model.setMenuVisible(true) }
        .onDisappear { model.setMenuVisible(false) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "rectangle.and.hand.point.up.left.filled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("TrackEdge").font(.headline)
                Text(deviceSummary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: $prefs.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var deviceSummary: String {
        if !prefs.enabled { return "Paused" }
        switch (model.hasTrackpad, model.hasMagicMouse && prefs.magicMouse) {
        case (true, true): return "Trackpad and Magic Mouse"
        case (true, false): return "Trackpad ready"
        case (false, true): return "Magic Mouse ready"
        case (false, false): return "No trackpad found"
        }
    }
}

/// A drawing of the trackpad that shows each edge's live value where it is controlled.
private struct EdgePreview: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: Preferences

    private let size = CGSize(width: 268, height: 150)

    var body: some View {
        let barWidth = min(max(size.width * prefs.edgeWidth, 12), 28)
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary.opacity(0.5))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)

            HStack {
                meter(for: prefs.swapSides ? .volume : .brightness, width: barWidth)
                Spacer()
                meter(for: prefs.swapSides ? .brightness : .volume, width: barWidth)
            }
            .padding(10)

            if prefs.quickMute {
                Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.slash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(model.muted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 12)
                    .padding(.trailing, barWidth + 18)
            }

            if prefs.mediaStrip {
                HStack(spacing: 8) {
                    Image(systemName: "backward.fill")
                    Capsule().fill(.tertiary).frame(height: 2)
                    Image(systemName: "playpause.fill")
                    Capsule().fill(.tertiary).frame(height: 2)
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, barWidth + 22)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
            }
        }
        .frame(width: size.width, height: size.height)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: prefs.edgeWidth)
    }

    private func meter(for control: Control, width: CGFloat) -> some View {
        let value: Double?
        let symbol: String
        switch control {
        case .volume:
            value = model.muted ? 0 : model.volume
            symbol = model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness:
            value = model.brightness
            symbol = "sun.max.fill"
        }
        return VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(height: 12)
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.tint)
                        .frame(height: proxy.size.height * CGFloat(value ?? 0))
                }
            }
            .frame(width: width)
            .animation(.easeOut(duration: 0.12), value: value)
            Text(value.map { "\(Int(($0 * 100).rounded()))" } ?? "--")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(control == .volume ? "Volume" : "Brightness")
        .accessibilityValue(value.map { "\(Int(($0 * 100).rounded())) percent" } ?? "Unavailable")
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }
}

private struct Callout: View {
    let symbol: String
    let text: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title, action: action.run).controlSize(.small)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
