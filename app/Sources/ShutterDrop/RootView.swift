import SwiftUI

/// The app's three tabs. Each tab's screen is filled in as the build goes.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Queue", systemImage: "square.stack") {
                PlaceholderScreen(title: "Queue")
            }
            Tab("Posted", systemImage: "checkmark.circle") {
                PlaceholderScreen(title: "Posted")
            }
            Tab("Settings", systemImage: "gearshape") {
                PlaceholderScreen(title: "Settings")
            }
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            Palette.background
                .ignoresSafeArea()
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
}
