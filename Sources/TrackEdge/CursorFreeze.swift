import AppKit

/// Keeps the pointer still and hidden while a finger slides along an edge.
///
/// The trackpad keeps sending pointer movement during a slide. An event tap drops
/// those events and pins the cursor where the slide began.
@MainActor
final class CursorFreeze {
    private var tap: CFMachPort?
    private var frozenAt: CGPoint?
    private var hidden = false

    var isInstalled: Bool { tap != nil }

    /// Creates the event tap. Fails until the app has Accessibility access.
    @discardableResult
    func install() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: cursorFreezeCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        return true
    }

    func begin() {
        guard frozenAt == nil else { return }
        frozenAt = CGEvent(source: nil)?.location
        CGAssociateMouseAndMouseCursorPosition(0)
        if !hidden {
            CursorVisibility.allowInBackground()
            CGDisplayHideCursor(CGMainDisplayID())
            hidden = true
        }
    }

    func end() {
        guard frozenAt != nil else { return }
        frozenAt = nil
        CGAssociateMouseAndMouseCursorPosition(1)
        if hidden {
            CGDisplayShowCursor(CGMainDisplayID())
            hidden = false
        }
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let point = frozenAt else { return Unmanaged.passUnretained(event) }
        if type != .scrollWheel { CGWarpMouseCursorPosition(point) }
        return nil
    }
}

private func cursorFreezeCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let freeze = Unmanaged<CursorFreeze>.fromOpaque(refcon).takeUnretainedValue()
    // Session event taps run on the run loop they were added to, which is the main one.
    return MainActor.assumeIsolated { freeze.handle(type, event) }
}

/// A background app may only hide the cursor after it sets this WindowServer property.
private enum CursorVisibility {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static let done: Void = {
        guard let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW),
              let connection = dlsym(handle, "_CGSDefaultConnection"),
              let property = dlsym(handle, "CGSSetConnectionProperty") else { return }
        let cid = unsafeBitCast(connection, to: DefaultConnection.self)()
        _ = unsafeBitCast(property, to: SetProperty.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }()

    static func allowInBackground() { _ = done }
}
