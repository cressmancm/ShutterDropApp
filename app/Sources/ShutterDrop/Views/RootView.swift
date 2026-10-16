import SwiftData
import SwiftUI

/// Decides what the app shows: the Apple Intelligence requirement screen,
/// onboarding on first launch, or the three tabs.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Intake.self) private var intake
    @AppStorage(AppSettings.onboardingDone) private var onboardingDone = false
    @State private var intelligence = AppleIntelligence.current

    var body: some View {
        Group {
            if intelligence != .ready && !DebugOptions.skipIntelligenceCheck {
                NeedsAppleIntelligenceView(state: intelligence)
            } else if !onboardingDone {
                OnboardingView()
            } else {
                MainTabs()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            intelligence = AppleIntelligence.current
            guard onboardingDone else { return }
            Task { await intake.syncAlbum(in: context) }
        }
        .task(id: intelligence) {
            // While the model downloads, check back until it's ready.
            while intelligence == .downloading {
                try? await Task.sleep(for: .seconds(5))
                intelligence = AppleIntelligence.current
            }
        }
    }
}

private struct MainTabs: View {
    @State private var tab = DebugOptions.startTab ?? "queue"

    var body: some View {
        TabView(selection: $tab) {
            Tab("Queue", systemImage: "square.stack", value: "queue") {
                QueueView()
            }
            Tab("Posted", systemImage: "checkmark.circle", value: "posted") {
                PostedView()
            }
            Tab("Settings", systemImage: "gearshape", value: "settings") {
                SettingsView()
            }
        }
    }
}
