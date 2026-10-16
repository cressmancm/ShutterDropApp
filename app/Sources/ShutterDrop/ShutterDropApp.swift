import SwiftData
import SwiftUI

@main
struct ShutterDropApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
        .modelContainer(for: Post.self)
    }
}
