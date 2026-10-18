import Observation
import PhotosUI
import SwiftData
import SwiftUI

/// How photos get into the queue and leave it: the ShutterDrop album, scanned
/// each time the app opens, and the photo picker.
@MainActor
@Observable
final class Intake {
    /// Background work the queue shows under its title.
    struct Progress: Equatable {
        enum Kind { case reading, writingAltText }
        var kind: Kind
        var done: Int
        var total: Int

        /// "Reading 12 of 150 photos…"
        var line: String {
            switch kind {
            case .reading: "Reading \(done + 1) of \(total) photo\(total == 1 ? "" : "s")…"
            case .writingAltText: "Writing alt text, \(done + 1) of \(total)…"
            }
        }
    }

    let library: PhotoLibrary
    let processor: PostProcessor
    private(set) var isWorking = false
    private(set) var isWritingAltText = false
    private(set) var progress: Progress?

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
            Log.intake.info("Album sync skipped: no photo library access")
            await processPending(in: context)
            return
        }
        let assets: [PHAsset]
        do {
            assets = try await library.albumAssets()
        } catch {
            Log.intake.error("Couldn't read the ShutterDrop album: \(error.localizedDescription, privacy: .public)")
            assets = []
        }
        let inAlbum = Set(assets.map(\.localIdentifier))
        let posts = (try? context.fetch(FetchDescriptor<Post>())) ?? []
        let known = Set(posts.map(\.assetID))

        // Filenames are filled in while each photo is read, off the main
        // thread; fetching them here for a big album stalls the app.
        var added = 0
        for asset in assets where !known.contains(asset.localIdentifier) {
            context.insert(Post(assetID: asset.localIdentifier, source: .album, dateTaken: asset.creationDate))
            added += 1
        }

        // With limited access the album only shows the photos the user picked,
        // so a missing photo may just be hidden; only full access removes.
        var removed = 0
        if library.hasFullAccess {
            for post in posts where post.source == .album && !post.isPosted && !inAlbum.contains(post.assetID) {
                context.delete(post)
                removed += 1
            }
        }
        try? context.save()
        Log.intake.info("Album sync: \(assets.count, privacy: .public) in the album, \(added, privacy: .public) new, \(removed, privacy: .public) removed")
        await processPending(in: context)
        await fillMissingAltText(in: context)
    }

    /// Adds photos chosen with the photo picker. ShutterDrop keeps its own copy
    /// because it may not be able to read them from the library later.
    func add(_ items: [PhotosPickerItem], in context: ModelContext) async {
        let posts = (try? context.fetch(FetchDescriptor<Post>())) ?? []
        var known = Set(posts.map(\.assetID))
        var added = 0
        for item in items {
            let id = item.itemIdentifier ?? "picked-\(UUID().uuidString)"
            guard !known.contains(id) else { continue }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let name = try? LocalImageStore.save(data)
            else {
                Log.intake.error("Couldn't load a photo from the picker")
                continue
            }
            let post = Post(assetID: id, source: .picker)
            post.localImageName = name
            if library.asset(withID: id) != nil {
                post.filename = await PhotoLibrary.filename(assetID: id)
            }
            context.insert(post)
            known.insert(id)
            added += 1
        }
        try? context.save()
        Log.intake.info("Picker: added \(added, privacy: .public) of \(items.count, privacy: .public) photos")
        await processPending(in: context)
    }

    /// Swipe to Remove: takes an album photo out of the ShutterDrop album (it
    /// stays in Photos) and drops the post.
    func remove(_ post: Post, in context: ModelContext) async {
        if post.source == .album {
            do {
                try await library.removeFromAlbum(assetID: post.assetID)
            } catch {
                Log.intake.error("Couldn't take a photo out of the album: \(error.localizedDescription, privacy: .public)")
            }
        }
        if let name = post.localImageName {
            LocalImageStore.delete(named: name)
        }
        context.delete(post)
        try? context.save()
        Log.intake.info("Removed a post")
    }

    /// Fills in every post that hasn't been processed yet, one at a time.
    func processPending(in context: ModelContext) async {
        guard !isWorking else { return }
        let pending = FetchDescriptor<Post>(predicate: #Predicate { $0.processedAt == nil && $0.sourceRaw != "imported" })
        let posts = (try? context.fetch(pending)) ?? []
        guard !posts.isEmpty else { return }

        isWorking = true
        defer {
            isWorking = false
            progress = nil
        }
        let clock = ContinuousClock()
        let start = clock.now
        Log.intake.info("Reading \(posts.count, privacy: .public) new photos")
        for (index, post) in posts.enumerated() {
            progress = Progress(kind: .reading, done: index, total: posts.count)
            await processor.process(post)
            try? context.save()
        }
        Log.intake.info("Read \(posts.count, privacy: .public) photos in \((clock.now - start).logText, privacy: .public)")
    }

    /// Writes alt text for queued posts that don't have any, when the user
    /// wants it and Apple Intelligence can run: after turning the setting on,
    /// or once Apple Intelligence finishes downloading or is turned on.
    func fillMissingAltText(in context: ModelContext) async {
        guard AppSettings.writesAltText, !isWritingAltText, !isWorking else { return }
        let missing = FetchDescriptor<Post>(predicate: #Predicate { !$0.isPosted && $0.processedAt != nil && $0.altText == "" })
        let posts = (try? context.fetch(missing)) ?? []
        guard !posts.isEmpty else { return }

        isWritingAltText = true
        defer {
            isWritingAltText = false
            progress = nil
        }
        Log.altText.info("Writing missing alt text for \(posts.count, privacy: .public) posts")
        for (index, post) in posts.enumerated() {
            guard AppSettings.writesAltText else {
                Log.altText.info("Stopped writing alt text: the setting was turned off")
                break
            }
            progress = Progress(kind: .writingAltText, done: index, total: posts.count)
            await processor.regenerateAltText(for: post)
            try? context.save()
        }
    }
}
