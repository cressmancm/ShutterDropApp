import FoundationModels
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intake.self) private var intake
    @AppStorage(AppSettings.locationLookups) private var lookups = true
    @AppStorage(AppSettings.altTextGeneration) private var writesAltText = true
    @AppStorage(AppSettings.privateCloudCompute) private var usesCloud = false
    @Environment(\.appleIntelligence) private var intelligence
    @Environment(\.openURL) private var openURL
    @State private var showingDebugTools = DebugOptions.openDebugTools

    var body: some View {
        NavigationStack {
            Form {
            Group {
                Section {
                    NavigationLink("Post Template") { TemplateEditorView() }
                } header: {
                    Text("Post")
                } footer: {
                    Text("The layout every post uses: tags, emojis, fixed text and line breaks.")
                }

                Section {
                    Toggle("Location Lookups", isOn: $lookups)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Sends each photo's location to Apple to find place names. When off, Location stays empty unless you type one.")
                }

                Section {
                    Toggle("Write Alt Text with Apple Intelligence", isOn: Binding(
                        get: { writesAltText && intelligence.isSupported },
                        set: { writesAltText = $0 }
                    ))
                    .disabled(!intelligence.isSupported)
                    if writesAltText && intelligence == .turnedOff {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Alt Text")
                } footer: {
                    Text(intelligence.altTextNote(enabled: writesAltText) ?? "You write alt text yourself on each post.")
                }
                .onChange(of: writesAltText) { _, on in
                    if on { Task { await intake.fillMissingAltText(in: context) } }
                }

                if CloudModel.isEntitled {
                    Section {
                        Toggle("Use Private Cloud Compute", isOn: Binding(
                            get: { usesCloud && CloudModel.isAvailable },
                            set: { usesCloud = $0 }
                        ))
                        .disabled(!CloudModel.isAvailable)
                        if usesCloud, let suggestion = CloudModel.limitIncreaseSuggestion {
                            Button("Get More with iCloud+") { suggestion.show() }
                        }
                    } header: {
                        Text("Private Cloud Compute")
                    } footer: {
                        Text((CloudModel.note.map { $0 + "\n\n" } ?? "") + "Sends each new photo to Apple's larger Apple Intelligence model, which uses it only for the request and doesn't store it. It recognizes the place the photo shows, writes richer alt text and suggests hashtags. Needs a connection and has a daily limit. When off, everything stays on this iPhone.")
                    }
                }

                Section {
                    LabeledContent("Album", value: PhotoLibrary.albumName)
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Add photos to the ShutterDrop album in Photos and they appear in your queue when you open the app.")
                }

                #if DEBUG
                Section {
                    NavigationLink {
                        DebugToolsView()
                    } label: {
                        Label("Debug Tools", systemImage: "ladybug")
                    }
                } footer: {
                    Text("Debug builds only. Force states and preview screens for testing.")
                }
                #endif

                Section("About") {
                    Link("Privacy", destination: URL(string: "https://cressmancm.github.io/ShutterDropApp/privacy/")!)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
                }
            .listRowBackground(Palette.surface)
        }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            #if DEBUG
            .navigationDestination(isPresented: $showingDebugTools) { DebugToolsView() }
            #endif
        }
    }
}

/// The post template, edited as plain text with tag chips to insert.
struct TemplateEditorView: View {
    @AppStorage(AppSettings.postTemplate) private var template = PostTemplate.defaultText
    @State private var selection: TextSelection?
    @State private var confirmingReset = false
    @FocusState private var editing: Bool

    var body: some View {
        Form {
            Group {
            Section {
                TextEditor(text: $template, selection: $selection)
                    .focused($editing)
                    .frame(minHeight: 240)
                    .font(.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Template")
            } footer: {
                Text("A line whose tags are all empty is left out of the post, along with its emoji and text.")
            }

            Section {
                FlowLayout(spacing: 8) {
                    ForEach(PostTemplate.Tag.allCases, id: \.self) { tag in
                        Button(tag.token) { insert(tag.token) }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("Insert a Tag")
            } footer: {
                Text("Tap a tag to add it where the cursor is.")
            }

            Section {
                Button("Reset to Default", role: .destructive) { confirmingReset = true }
                    .foregroundStyle(Palette.destructive)
            }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Post Template")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }
                    .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Reset the template to ShutterDrop's default?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset to Default", role: .destructive) { template = PostTemplate.defaultText }
        }
    }

    private func insert(_ token: String) {
        if case .selection(let range) = selection?.indices {
            template.replaceSubrange(range, with: token)
            let caret = template.index(range.lowerBound, offsetBy: token.count)
            selection = TextSelection(insertionPoint: caret)
        } else {
            template += token
        }
    }
}

/// Lays chips out in rows, wrapping as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(for: subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in rows(for: subviews, width: bounds.width).origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + rowHeight))
    }
}
