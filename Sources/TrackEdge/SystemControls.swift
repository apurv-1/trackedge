import AppKit
import AudioToolbox
import CoreAudio

/// Media keys as defined by IOKit's `NX_KEYTYPE_*` constants.
enum MediaKey: Int {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case play = 16
    case next = 17
    case previous = 18
}

/// Changes system state by posting the same events the hardware media keys send.
/// macOS then applies the change and shows its own on-screen display.
enum SystemControls {
    /// Presses and releases a media key. With `fine`, Shift-Option is held, which
    /// makes macOS move volume and brightness by a quarter step.
    static func press(_ key: MediaKey, fine: Bool = false) {
        post(key, down: true, fine: fine)
        post(key, down: false, fine: fine)
    }

    private static func post(_ key: MediaKey, down: Bool, fine: Bool) {
        var flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
        if fine { flags.formUnion([.shift, .option]) }
        let data1 = (key.rawValue << 16) | ((down ? 0xa : 0xb) << 8)
        let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: Readouts for the menu

    /// Output volume from 0 to 1, or nil when the output device has no volume control.
    static func volume() -> Double? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    static func isMuted() -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let getBrightness: GetBrightness? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    /// Built-in display brightness from 0 to 1, or nil when the display does not report it.
    static func brightness() -> Double? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        guard getBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
        return Double(value)
    }
}
