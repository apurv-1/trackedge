import SwiftUI

@main
struct TrackEdgeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
                .environmentObject(model.prefs)
        } label: {
            Image(systemName: "rectangle.and.hand.point.up.left.filled")
        }
        .menuBarExtraStyle(.window)
    }
}
