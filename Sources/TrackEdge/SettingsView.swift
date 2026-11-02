import SwiftUI

/// The settings window. A plain AppKit window, because a menu bar app has no
/// reliable way to open a SwiftUI `Settings` scene on every supported macOS version.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(model: AppModel) {
        if window == nil {
            let root = SettingsView()
                .environmentObject(model)
                .environmentObject(model.prefs)
            let created = NSWindow(contentViewController: NSHostingController(rootView: root))
            created.title = "TrackEdge Settings"
            created.styleMask = [.titled, .closable]
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        Form {
            Section("Layout") {
                Toggle("Swap sides", isOn: $prefs.swapSides)
                    .help("Put brightness on the right edge and volume on the left.")
                Toggle("Bottom quarter only", isOn: $prefs.bottomQuarterOnly)
                    .help("Only slides that start in the lower quarter of the trackpad count.")
            }

            Section("Activation") {
                Toggle("Require Fn or Option", isOn: $prefs.requireModifier)
                    .help("Edges respond only while Fn or Option is held.")
                Toggle("Fine control with Shift-Option", isOn: $prefs.fineControl)
                    .help("Hold Shift-Option while sliding for quarter steps.")
                Toggle("Freeze cursor while sliding", isOn: $prefs.freezeCursor)
                    .disabled(!model.trusted)
            }

            Section("Media strip") {
                Toggle("Double-tap to play or pause", isOn: $prefs.doubleTapPlayPause)
                Toggle("Reverse swipe direction", isOn: $prefs.reverseSwipe)
            }
            .disabled(!prefs.mediaStrip)

            Section {
                Toggle("Use Magic Mouse top edges", isOn: $prefs.magicMouse)
            } header: {
                Text("Devices")
            } footer: {
                if !model.hasMagicMouse {
                    Text("No Magic Mouse is connected.").foregroundStyle(.secondary)
                }
            }

            Section("General") {
                Picker("Appearance", selection: $prefs.appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Open at login", isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }
                ))
                if let error = model.loginItemError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Version", value: Bundle.main.shortVersion)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/apurv-1/trackedge")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
