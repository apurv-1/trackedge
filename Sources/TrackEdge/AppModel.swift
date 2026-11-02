import AppKit
import Combine
import TrackEdgeCore
import ServiceManagement

/// App-wide state shared by the menu and the settings window.
@MainActor
final class AppModel: ObservableObject {
    let prefs = Preferences()

    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var touchAvailable = true
    @Published private(set) var devices: [InputDevice] = []
    @Published private(set) var volume: Double?
    @Published private(set) var muted = false
    @Published private(set) var brightness: Double?
    @Published private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var loginItemError: String?

    private let controller: TouchController
    private var subscriptions: Set<AnyCancellable> = []
    private var readoutTimer: Timer?

    init() {
        controller = TouchController(prefs: prefs)
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApp.appearance = prefs.appearance.nsAppearance

        controller.onDevicesChanged = { [weak self] in self?.devices = $0 }
        controller.onValuesChanged = { [weak self] in self?.refreshReadouts() }
        touchAvailable = controller.start()

        prefs.$enabled
            .dropFirst()
            .sink { [weak self] enabled in
                if !enabled { self?.controller.cancelGestures() }
            }
            .store(in: &subscriptions)

        // macOS posts this when any app's Accessibility access changes.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { self?.updateTrust() }
            }
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
        if trusted { controller.accessibilityGranted() }
        refreshReadouts()
    }

    var hasTrackpad: Bool { devices.contains { $0.surface == .trackpad } }
    var hasMagicMouse: Bool { devices.contains { $0.surface == .magicMouse } }

    func refreshReadouts() {
        volume = SystemControls.volume()
        muted = SystemControls.isMuted()
        brightness = SystemControls.brightness()
    }

    /// Keeps the menu's readouts current while it is open.
    func setMenuVisible(_ visible: Bool) {
        readoutTimer?.invalidate()
        readoutTimer = nil
        guard visible else { return }
        refreshReadouts()
        updateTrust()
        readoutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshReadouts() }
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateTrust() {
        let now = AXIsProcessTrusted()
        if now && !trusted { controller.accessibilityGranted() }
        trusted = now
    }
}
