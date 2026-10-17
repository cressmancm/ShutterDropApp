import SwiftData
import SwiftUI

/// Decides what the app shows: onboarding on first launch, then the three
/// tabs. Also keeps the Apple Intelligence state current for every screen.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Intake.self) private var intake
    @AppStorage(AppSettings.onboardingDone) private var onboardingDone = false
    @AppStorage(DebugOptions.intelligenceStateKey) private var forcedIntelligence = ""
    @State private var intelligence = AppleIntelligence.current

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView()
            } else {
                MainTabs()
            }
        }
        .environment(\.appleIntelligence, intelligence)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            intelligence = AppleIntelligence.current
            guard onboardingDone else { return }
            Task { await intake.syncAlbum(in: context) }
        }
        .onChange(of: forcedIntelligence) { intelligence = AppleIntelligence.current }
        .task(id: intelligence) {
            if intelligence == .ready, onboardingDone {
                // Alt text for photos that came in while it couldn't run.
                await intake.fillMissingAltText(in: context)
            }
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
