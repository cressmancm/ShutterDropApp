import Observation
import PhotosUI
import SwiftData
import SwiftUI

/// How photos get into the queue and leave it: the ShutterDrop album, scanned
/// each time the app opens, and the photo picker.
@MainActor
@Observable
final class Intake {
    let library: PhotoLibrary
    let processor: PostProcessor
    private(set) var isWorking = false
    private(set) var isWritingAltText = false

    init(library: PhotoLibrary = PhotoLibrary()) {
        self.library = library
        self.processor = PostProcessor(library: library)
    }

    /// Brings the queue in line with the album: new photos are added, and
    /// photos that left the album or were deleted leave the queue. Posted
    /// photos stay in Posted either way.
    func syncAlbum(in context: ModelContext) async {
        library.refreshStatus()
        guard library.canReadAlbum else {
            await processPending(in: context)
            return
        }
        let assets = (try? await library.albumAssets()) ?? []
        let inAlbum = Set(assets.map(\.localIdentifier))
        let posts = (try? context.fetch(FetchDescriptor<Post>())) ?? []
        let known = Set(posts.map(\.assetID))

        for asset in assets where !known.contains(asset.localIdentifier) {
            let post = Post(
                assetID: asset.localIdentifier,
                source: .album,
                filename: library.filename(of: asset),
                dateTaken: asset.creationDate
            )
            context.insert(post)
        }

        // With limited access the album only shows the photos the user picked,
        // so a missing photo may just be hidden; only full access removes.
        if library.hasFullAccess {
            for post in posts where post.source == .album && !post.isPosted && !inAlbum.contains(post.assetID) {
                context.delete(post)
            }
        }
        try? context.save()
        await processPending(in: context)
        await fillMissingAltText(in: context)
    }

    /// Adds photos chosen with the photo picker. ShutterDrop keeps its own copy
    /// because it may not be able to read them from the library later.
    func add(_ items: [PhotosPickerItem], in context: ModelContext) async {
        let posts = (try? context.fetch(FetchDescriptor<Post>())) ?? []
        var known = Set(posts.map(\.assetID))
        for item in items {
            let id = item.itemIdentifier ?? "picked-\(UUID().uuidString)"
            guard !known.contains(id),
                  let data = try? await item.loadTransferable(type: Data.self),
                  let name = try? LocalImageStore.save(data)
            else { continue }
            let post = Post(assetID: id, source: .picker)
            post.localImageName = name
            if let asset = library.asset(withID: id) {
                post.filename = library.filename(of: asset)
            }
            context.insert(post)
            known.insert(id)
        }
        try? context.save()
        await processPending(in: context)
    }

    /// Swipe to Remove: takes an album photo out of the ShutterDrop album (it
    /// stays in Photos) and drops the post.
    func remove(_ post: Post, in context: ModelContext) async {
        if post.source == .album {
            try? await library.removeFromAlbum(assetID: post.assetID)
        }
        if let name = post.localImageName {
            LocalImageStore.delete(named: name)
        }
        context.delete(post)
        try? context.save()
    }

    /// Fills in every post that hasn't been processed yet, one at a time.
    func processPending(in context: ModelContext) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let pending = FetchDescriptor<Post>(predicate: #Predicate { $0.processedAt == nil && $0.sourceRaw != "imported" })
        for post in (try? context.fetch(pending)) ?? [] {
            await processor.process(post)
            try? context.save()
        }
    }

    /// Writes alt text for queued posts that don't have any, when the user
    /// wants it and Apple Intelligence can run: after turning the setting on,
    /// or once Apple Intelligence finishes downloading or is turned on.
    func fillMissingAltText(in context: ModelContext) async {
        guard AppSettings.writesAltText, !isWritingAltText else { return }
        isWritingAltText = true
        defer { isWritingAltText = false }
        let missing = FetchDescriptor<Post>(predicate: #Predicate { !$0.isPosted && $0.processedAt != nil && $0.altText == "" })
        for post in (try? context.fetch(missing)) ?? [] {
            guard AppSettings.writesAltText else { break }
            await processor.regenerateAltText(for: post)
            try? context.save()
        }
    }
}
