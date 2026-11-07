import SwiftUI

@main
struct ForceBridgeApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.ink)
        }
    }
}
