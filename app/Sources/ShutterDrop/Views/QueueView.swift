import PhotosUI
import SwiftData
import SwiftUI

/// Photos waiting to be posted, newest date taken first.
struct QueueView: View {
    @Environment(\.modelContext) private var context
    @Environment(Intake.self) private var intake
    @Query(filter: #Predicate<Post> { !$0.isPosted }) private var posts: [Post]
    @State private var picked: [PhotosPickerItem] = []
    @State private var path: [Post] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(posts.sortedByDateTaken) { post in
                    NavigationLink(value: post) {
                        PostRow(post: post)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Mark Posted", systemImage: "checkmark.circle") {
                            withAnimation { post.setPosted(true) }
                        }
                        .tint(Palette.accent)
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            Task { await intake.remove(post, in: context) }
                        }
                        .tint(Palette.destructive)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .overlay {
                if posts.isEmpty {
                    ContentUnavailableView {
                        Label("No Photos to Post", systemImage: "photo.stack")
                    } description: {
                        Text("Add photos to the ShutterDrop album in Photos, or choose some here.")
                    } actions: {
                        addPhotosPicker {
                            Text("Add Photos")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationDestination(for: Post.self) { PostDetailView(post: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addPhotosPicker {
                        Label("Add Photos", systemImage: "plus")
                    }
                }
            }
            .refreshable { await intake.syncAlbum(in: context) }
            .task {
                if DebugOptions.openFirstPost, let first = posts.sortedByDateTaken.first { path = [first] }
            }
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    await intake.add(items, in: context)
                    picked = []
                }
            }
        }
    }

    /// With library access the picker reports each photo's library ID, so a
    /// photo added both ways isn't queued twice. Without access it's left out:
    /// linking the picker to the library would bring up the permission prompt.
    @ViewBuilder
    private func addPhotosPicker<Label: View>(@ViewBuilder label: @escaping @Sendable () -> Label) -> some View {
        if intake.library.canReadAlbum {
            PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared(), label: label)
        } else {
            PhotosPicker(selection: $picked, matching: .images, label: label)
        }
    }
}

/// Photos that have been posted, newest date taken first.
struct PostedView: View {
    @Query(filter: #Predicate<Post> { $0.isPosted }) private var posts: [Post]

    var body: some View {
        NavigationStack {
            List {
                ForEach(posts.sortedByDateTaken) { post in
                    NavigationLink(value: post) {
                        PostRow(post: post)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .overlay {
                if posts.isEmpty {
                    ContentUnavailableView(
                        "Nothing Posted Yet",
                        systemImage: "checkmark.circle",
                        description: Text("Photos you mark as posted show up here.")
                    )
                }
            }
            .navigationTitle("Posted")
            .navigationDestination(for: Post.self) { PostDetailView(post: $0) }
        }
    }
}

extension Array where Element == Post {
    /// Newest date taken first; photos without a date go last.
    var sortedByDateTaken: [Post] {
        sorted { ($0.dateTaken ?? .distantPast) > ($1.dateTaken ?? .distantPast) }
    }
}
