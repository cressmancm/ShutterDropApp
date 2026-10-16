import SwiftData
import SwiftUI

@main
struct ShutterDropApp: App {
    @State private var intake = Intake()
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Post.self)
        } catch {
            fatalError("ShutterDrop couldn't open its post store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(intake)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .onAppear { DebugOptions.insertSampleData(into: container.mainContext) }
        }
        .modelContainer(container)
    }
}
