import SwiftData
import SwiftUI

/// Everything needed to post one photo on one screen: the photo, the caption,
/// the finished post as it will be pasted, the details, and the copy buttons.
struct PostDetailView: View {
    @Bindable var post: Post

    @Environment(\.modelContext) private var context
    @Environment(Intake.self) private var intake
    @AppStorage(AppSettings.postTemplate) private var template = PostTemplate.defaultText
    @AppStorage(AppSettings.hashtagSearchSite) private var searchSite = AppSettings.defaultHashtagSearchSite
    @Query private var allPosts: [Post]

    @State private var copiedPost = false
    @State private var copiedAlt = false
    @State private var regenerating = false
    @State private var askingSearchTerm = false
    @State private var searchTerm = ""
    @State private var searchPage: IdentifiableURL?
    @State private var showingPhoto = false
    @FocusState private var editing: Bool

    var body: some View {
        Form {
            Group {
            Section {
                Button { showingPhoto = true } label: {
                    PostImage(post: post, loadSize: CGSize(width: 400, height: 300))
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the photo full screen")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Caption") {
                TextField("Write a caption (optional)", text: $post.caption, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($editing)
            }

            Section("Preview") {
                Text(post.render(with: template))
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .foregroundStyle(Palette.text)
            }

            Section {
                Toggle("Posted", isOn: Binding(get: { post.isPosted }, set: { post.setPosted($0) }))
            } footer: {
                Text("Turn on after you post. The photo moves to the Posted tab.")
            }

            Section("Details") {
                LabeledField("Location", text: $post.location, focus: $editing)
                LabeledField("Camera", text: $post.cameraLine, focus: $editing)
                LabeledField("Exposure", text: $post.exposure, focus: $editing)
                LabeledField("Date Taken", text: $post.dateText, focus: $editing)
            }

            hashtagsSection

            Section("Alt Text") {
                TextField("Alt text", text: $post.altText, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($editing)
                Button {
                    Task {
                        regenerating = true
                        await intake.processor.regenerateAltText(for: post)
                        regenerating = false
                    }
                } label: {
                    HStack {
                        Label("Regenerate Alt Text", systemImage: "arrow.clockwise")
                        if regenerating { Spacer(); ProgressView() }
                    }
                }
                .disabled(regenerating)
            }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }
                    .fontWeight(.semibold)
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sensoryFeedback(.success, trigger: copiedPost) { _, new in new }
        .sensoryFeedback(.success, trigger: copiedAlt) { _, new in new }
        .alert("Search Hashtags", isPresented: $askingSearchTerm) {
            TextField("Search for", text: $searchTerm)
                .textInputAutocapitalization(.never)
            Button("Search") {
                if let url = Hashtags.searchURL(site: searchSite, term: searchTerm) {
                    searchPage = IdentifiableURL(url: url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Copy the tags you want from the results, then come back and paste them.")
        }
        .sheet(item: $searchPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingPhoto) {
            FullScreenPhoto(post: post)
        }
        .onDisappear { try? context.save() }
    }

    private var hashtagsSection: some View {
        Section {
            TextField("#hashtags", text: $post.hashtags, axis: .vertical)
                .focused($editing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: post.hashtags) { old, new in
                    // A paste that adds more than a tag's worth of text gets
                    // cleaned down to its #tags.
                    if new.count - old.count > 1 && new.contains(where: \.isNewline) || new.count - old.count > 40 {
                        post.hashtags = Hashtags.clean(new)
                    }
                }
            let suggestions = Hashtags.suggestions(
                location: post.location,
                camera: post.cameraModel,
                current: post.hashtags,
                history: allPosts.filter { $0.assetID != post.assetID }.map(\.hashtags)
            )
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { tag in
                            Button("+ \(tag)") {
                                post.hashtags = Hashtags.adding([tag], to: post.hashtags)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                        }
                    }
                }
            }
            Button("Search Hashtags", systemImage: "number") {
                searchTerm = Hashtags.searchTerm(location: post.location, sceneLabels: post.sceneLabels)
                askingSearchTerm = true
            }
            PasteButton(payloadType: String.self) { strings in
                post.hashtags = Hashtags.adding(Hashtags.extract(from: strings.joined(separator: " ")), to: post.hashtags)
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
        } header: {
            Text("Hashtags")
        } footer: {
            Text("Paste any text with hashtags; only the #tags are kept. Suggestions come from tags you've used and the place name.")
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = post.render(with: template)
                    flash($copiedPost)
                } label: {
                    Label(copiedPost ? "Copied" : "Copy Post", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    UIPasteboard.general.string = post.altText
                    flash($copiedAlt)
                } label: {
                    Label(copiedAlt ? "Copied" : "Copy Alt Text", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .disabled(post.altText.isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                UIPasteboard.general.string = post.render(with: template)
                Task {
                    guard let data = await intake.processor.imageData(for: post) else { return }
                    InstagramSharer.shared.share(imageData: data)
                }
            } label: {
                Label("Open in Instagram", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Palette.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .background(.bar)
    }

    private func flash(_ flag: Binding<Bool>) {
        flag.wrappedValue = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            flag.wrappedValue = false
        }
    }
}

/// A small label above an editable value, as in the design.
private struct LabeledField: View {
    let title: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    init(_ title: String, text: Binding<String>, focus: FocusState<Bool>.Binding) {
        self.title = title
        self._text = text
        self.focus = focus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
            TextField(title, text: $text, axis: .vertical)
                .focused(focus)
        }
    }
}

private struct FullScreenPhoto: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PostImage(post: post, loadSize: CGSize(width: 1200, height: 1200))
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
