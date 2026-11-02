import AppKit
import TrackEdgeCore

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum HapticStrength: Int, CaseIterable, Identifiable {
    case off, light, medium, strong

    var id: Int { rawValue }
    var title: String { String(describing: self).capitalized }

    /// MultitouchSupport actuation waveform for this strength.
    var actuationID: Int32? {
        switch self {
        case .off: return nil
        case .light: return 3
        case .medium: return 4
        case .strong: return 6
        }
    }
}

/// User settings, stored in UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults

    @Published var enabled: Bool { didSet { save(enabled, "enabled") } }
    @Published var edgeWidth: Double { didSet { save(edgeWidth, "edgeWidth") } }
    @Published var sensitivity: Double { didSet { save(sensitivity, "sensitivity") } }
    @Published var haptics: HapticStrength { didSet { save(haptics.rawValue, "haptics") } }
    @Published var swapSides: Bool { didSet { save(swapSides, "swapSides") } }
    @Published var bottomQuarterOnly: Bool { didSet { save(bottomQuarterOnly, "bottomQuarterOnly") } }
    @Published var requireModifier: Bool { didSet { save(requireModifier, "requireModifier") } }
    @Published var freezeCursor: Bool { didSet { save(freezeCursor, "freezeCursor") } }
    @Published var fineControl: Bool { didSet { save(fineControl, "fineControl") } }
    @Published var preciseSliding: Bool { didSet { save(preciseSliding, "preciseSliding") } }
    @Published var mediaStrip: Bool { didSet { save(mediaStrip, "mediaStrip") } }
    @Published var reverseSwipe: Bool { didSet { save(reverseSwipe, "reverseSwipe") } }
    @Published var doubleTapPlayPause: Bool { didSet { save(doubleTapPlayPause, "doubleTapPlayPause") } }
    @Published var quickMute: Bool { didSet { save(quickMute, "quickMute") } }
    @Published var magicMouse: Bool { didSet { save(magicMouse, "magicMouse") } }
    @Published var appearance: Appearance {
        didSet {
            save(appearance.rawValue, "appearance")
            NSApp.appearance = appearance.nsAppearance
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "enabled": true,
            "edgeWidth": 0.08,
            "sensitivity": 1.0,
            "haptics": HapticStrength.light.rawValue,
            "freezeCursor": true,
            "fineControl": true,
            "mediaStrip": true,
            "doubleTapPlayPause": true,
            "quickMute": true,
            "appearance": Appearance.system.rawValue,
        ])
        enabled = defaults.bool(forKey: "enabled")
        edgeWidth = defaults.double(forKey: "edgeWidth")
        sensitivity = defaults.double(forKey: "sensitivity")
        haptics = HapticStrength(rawValue: defaults.integer(forKey: "haptics")) ?? .light
        swapSides = defaults.bool(forKey: "swapSides")
        bottomQuarterOnly = defaults.bool(forKey: "bottomQuarterOnly")
        requireModifier = defaults.bool(forKey: "requireModifier")
        freezeCursor = defaults.bool(forKey: "freezeCursor")
        fineControl = defaults.bool(forKey: "fineControl")
        preciseSliding = defaults.bool(forKey: "preciseSliding")
        mediaStrip = defaults.bool(forKey: "mediaStrip")
        reverseSwipe = defaults.bool(forKey: "reverseSwipe")
        doubleTapPlayPause = defaults.bool(forKey: "doubleTapPlayPause")
        quickMute = defaults.bool(forKey: "quickMute")
        magicMouse = defaults.bool(forKey: "magicMouse")
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
    }

    func engineConfig(for surface: Surface) -> EdgeConfig {
        var config = EdgeConfig()
        config.edgeWidth = edgeWidth
        config.sensitivity = sensitivity
        config.swapSides = swapSides
        config.bottomQuarterOnly = bottomQuarterOnly
        config.preciseSliding = preciseSliding
        config.mediaStrip = mediaStrip
        config.reverseSwipe = reverseSwipe
        config.doubleTapPlayPause = doubleTapPlayPause
        config.quickMute = quickMute
        config.surface = surface
        return config
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
