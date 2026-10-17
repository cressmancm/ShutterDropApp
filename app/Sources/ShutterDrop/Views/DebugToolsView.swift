#if DEBUG
import Photos
import SwiftData
import SwiftUI

/// Settings › Debug Tools, in Debug builds only: force ShutterDrop into each
/// state and preview each screen, to test and review without leaving the app.
struct DebugToolsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(Intake.self) private var intake
    @AppStorage(DebugOptions.intelligenceStateKey) private var forcedIntelligence = ""
    @AppStorage(AppSettings.onboardingDone) private var onboardingDone = false
    @Query private var posts: [Post]

    @State private var preview: Preview?
    @State private var confirmingDelete = false
    @State private var confirmingReset = false
    @State private var reprocessing = false

    enum Preview: String, Identifiable {
        case onboarding
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Group {
                Section {
                    Picker("State", selection: $forcedIntelligence) {
                        ForEach(DebugOptions.intelligenceStates, id: \.value) { state in
                            Text(state.label).tag(state.value)
                        }
                    }
                    LabeledContent("This Device", value: deviceState)
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("Changes what the Alt Text setting, the post screen and the onboarding Alt Text step say and offer, and whether alt text gets written.")
                }

                Section {
                    Button("Preview Onboarding") { preview = .onboarding }
                } footer: {
                    Text("Opens onboarding on its own, as it looks in the state above. It doesn't ask for access or save any answer.")
                }

                Section {
                    Button("Restart Onboarding") { onboardingDone = false }
                } footer: {
                    Text("Leaves Settings and runs the real onboarding, including the photo access prompt if it hasn't been answered.")
                }

                Section {
                    LabeledContent("In Queue", value: "\(posts.filter { !$0.isPosted }.count)")
                    LabeledContent("Posted", value: "\(posts.filter(\.isPosted).count)")
                    Button("Add Sample Posts") { DebugOptions.addSamplePosts(into: context) }
                    Button("Mark All as Not Posted") {
                        posts.forEach { $0.setPosted(false) }
                        try? context.save()
                    }
                    .disabled(!posts.contains(where: \.isPosted))
                    Button {
                        Task {
                            reprocessing = true
                            for post in posts where post.source != .imported { post.processedAt = nil }
                            await intake.processPending(in: context)
                            reprocessing = false
                        }
                    } label: {
                        HStack {
                            Text("Read All Photos Again")
                            if reprocessing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(reprocessing)
                    Button("Delete All Posts", role: .destructive) { confirmingDelete = true }
                        .foregroundStyle(Palette.destructive)
                        .disabled(posts.isEmpty)
                } header: {
                    Text("Posts")
                } footer: {
                    Text("Sample posts have no photo. Deleting every post shows the empty queue. Reading photos again refills details, place names and alt text, replacing edits to those fields.")
                }

                Section {
                    LabeledContent("Access", value: photoAccess)
                    if intake.library.status == .notDetermined {
                        Button("Ask for Photo Access") { Task { await intake.library.requestAccess() } }
                    }
                    Button("Open ShutterDrop in iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    Button("Sync the Album Now") { Task { await intake.syncAlbum(in: context) } }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("iOS asks only once. To see the prompt again, delete the app; in the simulator, erase it too.")
                }

                Section {
                    Button("Reset ShutterDrop's Settings", role: .destructive) { confirmingReset = true }
                        .foregroundStyle(Palette.destructive)
                } footer: {
                    Text("Puts back the default post template, search site, Location Lookups and alt text setting, and clears the forced Apple Intelligence state. Posts stay.")
                }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { intake.library.refreshStatus() }
        .fullScreenCover(item: $preview) { preview in
            PreviewContainer(preview: preview)
        }
        .confirmationDialog("Delete all \(posts.count) posts?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete All Posts", role: .destructive) {
                for post in posts {
                    if let name = post.localImageName { LocalImageStore.delete(named: name) }
                    context.delete(post)
                }
                try? context.save()
            }
        } message: {
            Text("Photos in your library aren't touched.")
        }
        .confirmationDialog("Reset ShutterDrop's settings?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset Settings", role: .destructive) {
                for key in [AppSettings.postTemplate, AppSettings.locationLookups, AppSettings.hashtagSearchSite, AppSettings.altTextGeneration, DebugOptions.intelligenceStateKey] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    private var deviceState: String {
        switch AppleIntelligence.device {
        case .ready: "Ready"
        case .unsupportedDevice: "Not Supported"
        case .turnedOff: "Turned Off"
        case .downloading: "Downloading"
        }
    }

    private var photoAccess: String {
        switch intake.library.status {
        case .authorized: "Full"
        case .limited: "Limited"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Asked Yet"
        @unknown default: "Unknown"
        }
    }
}

/// A screen shown on its own, with a Close button, so trying it changes
/// nothing. The onboarding preview keeps its answers to itself.
private struct PreviewContainer: View {
    let preview: DebugToolsView.Preview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch preview {
            case .onboarding:
                OnboardingView(preview: true, onFinish: { dismiss() })
                    .environment(\.appleIntelligence, AppleIntelligence.current)
            }
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .padding()
        }
    }
}
#endif
