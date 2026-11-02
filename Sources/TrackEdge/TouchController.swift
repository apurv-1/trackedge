import AppKit
import CMultitouch
import IOKit
import TrackEdgeCore

struct InputDevice: Equatable {
    let index: Int32
    let surface: Surface
    let builtIn: Bool
}

/// Reads touches from every multitouch device, runs one gesture engine per device,
/// and turns the resulting actions into system changes.
@MainActor
final class TouchController {
    private let prefs: Preferences
    private let cursor = CursorFreeze()
    private var engines: [Int32: EdgeGestureEngine] = [:]
    private var notifyPort: IONotificationPortRef?
    private var pendingRestart: DispatchWorkItem?

    private(set) var devices: [InputDevice] = []
    var onDevicesChanged: (([InputDevice]) -> Void)?
    /// Called after an action changes volume, brightness, or mute.
    var onValuesChanged: (() -> Void)?

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    /// Returns false when MultitouchSupport cannot be loaded on this system.
    func start() -> Bool {
        guard LMTLoad() else { return false }
        restart()
        watchDevices()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRestart() }
        }
        return true
    }

    /// Installs the cursor-freeze event tap once Accessibility access exists.
    func accessibilityGranted() {
        cursor.install()
    }

    /// Ends any gesture in progress, for example when TrackEdge is switched off.
    func cancelGestures() {
        for engine in engines.values {
            perform(engine.reset(), device: -1)
        }
    }

    // MARK: Devices

    private func restart() {
        cancelGestures()
        let count = LMTStart(frameHandler, Unmanaged.passUnretained(self).toOpaque())
        devices = (0..<count).map { index in
            let family = LMTDeviceFamily(index)
            let surface: Surface = (family == 112 || family == 113) ? .magicMouse : .trackpad
            return InputDevice(index: index, surface: surface, builtIn: LMTDeviceIsBuiltIn(index))
        }
        engines = Dictionary(uniqueKeysWithValues: devices.map { ($0.index, EdgeGestureEngine()) })
        onDevicesChanged?(devices)
    }

    /// Restarts shortly after a change, so a burst of IOKit notifications causes one restart.
    func scheduleRestart() {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.restart() }
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    /// Restarts input when a trackpad or Magic Mouse connects or disconnects.
    private func watchDevices() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port, type, IOServiceMatching("AppleMultitouchDevice"), deviceChangedCallback, refcon, &iterator
            )
            // Draining the iterator arms the notification. The existing devices are already running.
            if result == KERN_SUCCESS { drain(iterator) }
        }
    }

    // MARK: Frames and actions

    fileprivate func handle(device index: Int32, touches: [Touch], time: Double) {
        guard prefs.enabled,
              let device = devices.first(where: { $0.index == index }),
              let engine = engines[index] else { return }
        if device.surface == .magicMouse && !prefs.magicMouse { return }

        engine.config = prefs.engineConfig(for: device.surface)
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let gateOpen = !prefs.requireModifier || flags.contains(.maskSecondaryFn) || flags.contains(.maskAlternate)
        let fineHeld = prefs.fineControl && flags.contains(.maskShift) && flags.contains(.maskAlternate)
        perform(engine.process(touches: touches, time: time, gateOpen: gateOpen, fineHeld: fineHeld), device: index)
    }

    private func perform(_ actions: [EdgeAction], device: Int32) {
        for action in actions {
            switch action {
            case .slideBegan:
                if prefs.freezeCursor && cursor.isInstalled { cursor.begin() }
            case let .step(control, count, fine):
                let key: MediaKey
                switch control {
                case .volume: key = count > 0 ? .soundUp : .soundDown
                case .brightness: key = count > 0 ? .brightnessUp : .brightnessDown
                }
                for _ in 0..<abs(count) { SystemControls.press(key, fine: fine) }
                tick(device)
                onValuesChanged?()
            case .slideEnded:
                cursor.end()
            case .toggleMute:
                SystemControls.press(.mute)
                tick(device)
                onValuesChanged?()
            case .playPause:
                SystemControls.press(.play)
                tick(device)
            case .nextTrack:
                SystemControls.press(.next)
                tick(device)
            case .previousTrack:
                SystemControls.press(.previous)
                tick(device)
            }
        }
    }

    private func tick(_ device: Int32) {
        guard let actuationID = prefs.haptics.actuationID else { return }
        if !LMTActuate(device, actuationID) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

/// MultitouchSupport state codes 4 and 5 mean the finger is touching the surface.
private let touchingStates: Set<Int32> = [4, 5]

private let frameHandler: LMTFrameHandler = { index, touches, count, timestamp, context in
    guard let context else { return }
    var points: [Touch] = []
    if let touches {
        for i in 0..<Int(count) where touchingStates.contains(touches[i].state) {
            let touch = touches[i]
            points.append(Touch(id: Int(touch.identifier),
                                x: Double(touch.normalized.position.x),
                                y: Double(touch.normalized.position.y)))
        }
    }
    let controller = Unmanaged<TouchController>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated { controller.handle(device: index, touches: points, time: timestamp) }
    }
}

private func deviceChangedCallback(refcon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    drain(iterator)
    guard let refcon else { return }
    let controller = Unmanaged<TouchController>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { controller.scheduleRestart() }
}

private func drain(_ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
    }
}
