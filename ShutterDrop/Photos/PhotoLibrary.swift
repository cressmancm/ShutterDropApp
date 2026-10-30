import Observation
import OSLog
import Photos
import UIKit

/// The ShutterDrop album in Photos, and reading photos from the library.
///
/// Photos runs change blocks and some result handlers on its own queues, so
/// every closure handed to PhotoKit is `@Sendable`: a closure tied to the main
/// actor would stop the app when Photos calls it from another thread.
@Observable
final class PhotoLibrary {
    nonisolated static let albumName = "ShutterDrop"

    private(set) var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    /// Full access: ShutterDrop can create the album and take photos out of it.
    var hasFullAccess: Bool { status == .authorized }
    /// Full or limited access: ShutterDrop can read the album.
    var canReadAlbum: Bool { status == .authorized || status == .limited }

    func refreshStatus() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    @discardableResult
    func requestAccess() async -> PHAuthorizationStatus {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status
    }

    /// The ShutterDrop album, made first when it's missing and ShutterDrop has
    /// full access.
    func album() async throws -> PHAssetCollection? {
        if let album = existingAlbum() { return album }
        guard hasFullAccess else { return nil }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: PhotoLibrary.albumName)
        }
        return existingAlbum()
    }

    /// The photos in the ShutterDrop album that ShutterDrop is allowed to see.
    func albumAssets() async throws -> [PHAsset] {
        guard canReadAlbum, let album = try await album() else { return [] }
        let result = PHAsset.fetchAssets(in: album, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    /// Takes a photo out of the ShutterDrop album. The photo stays in the library.
    func removeFromAlbum(assetID: String) async throws {
        guard hasFullAccess, let albumID = existingAlbum()?.localIdentifier else { return }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject,
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
            else { return }
            PHAssetCollectionChangeRequest(for: album)?.removeAssets([asset] as NSArray)
        }
    }

    /// Nil without library access. Any PhotoKit fetch before the user has
    /// answered would bring up the permission prompt unasked, so every read
    /// checks first.
    func asset(withID id: String) -> PHAsset? {
        guard canReadAlbum else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// The photo's original file name, like DSC_0001.NEF or IMG_1234.HEIC.
    /// Photos fetches it on demand, which is slow on the main thread with a
    /// big album, so this runs elsewhere.
    @concurrent
    nonisolated static func filename(assetID: String) async -> String {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return "" }
        return PHAssetResource.assetResources(for: asset).first?.filename ?? ""
    }

    /// The photo's full image data, downloaded from iCloud when the library
    /// keeps only a small copy on this iPhone.
    func imageData(for asset: PHAsset) async throws -> Data {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { @Sendable data, _, _, info in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    let error = info?[PHImageErrorKey] as? Error ?? CocoaError(.fileReadUnknown)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// A display-size image of the photo, for lists and the post screen.
    func image(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { @Sendable image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func existingAlbum() -> PHAssetCollection? {
        guard canReadAlbum else { return nil }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", Self.albumName)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }
}

#if DEBUG
extension PhotoLibrary {
    /// Debug Tools: adds the library's newest photos to the ShutterDrop album,
    /// to try a big album without filling it by hand.
    func addNewestPhotosToAlbum(count: Int) async {
        guard hasFullAccess, let albumID = try? await album()?.localIdentifier else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.fetchLimit = count
                let photos = PHAsset.fetchAssets(with: .image, options: options)
                guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject else { return }
                PHAssetCollectionChangeRequest(for: album)?.addAssets(photos)
            }
            Log.intake.info("Debug: added up to \(count, privacy: .public) photos to the album")
        } catch {
            Log.intake.error("Debug: couldn't add photos to the album: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
