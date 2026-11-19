import SwiftUI

@main
struct VPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = PlayerViewModel()
    @StateObject private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 600, idealHeight: 680)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands { AppCommands() }
    }
}
