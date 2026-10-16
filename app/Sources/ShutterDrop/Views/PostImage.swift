import SwiftUI
import UIKit

/// A post's photo, loaded from Photos or from ShutterDrop's own copy.
struct PostImage: View {
    let post: Post
    /// The size to load, in points; the view itself fills its frame.
    var loadSize: CGSize = CGSize(width: 120, height: 120)

    @Environment(Intake.self) private var intake
    @Environment(\.displayScale) private var scale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Palette.raised
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .clipped()
        .accessibilityLabel(post.altText.isEmpty ? Text("Photo") : Text(post.altText))
        .task(id: post.assetID) { image = await load() }
    }

    private func load() async -> UIImage? {
        let pixels = CGSize(width: loadSize.width * scale, height: loadSize.height * scale)
        if let name = post.localImageName, let data = LocalImageStore.data(named: name) {
            let maxPixels = Int(max(pixels.width, pixels.height))
            return PhotoDetailsReader.previewImage(from: data, maxPixelSize: maxPixels).map { UIImage(cgImage: $0) }
        }
        guard let asset = intake.library.asset(withID: post.assetID) else { return nil }
        return await intake.library.image(for: asset, size: pixels)
    }
}

/// One row in the Queue and Posted lists.
struct PostRow: View {
    let post: Post

    var body: some View {
        HStack(spacing: 12) {
            PostImage(post: post)
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(post.location.isEmpty ? "No location" : post.location)
                    .foregroundStyle(post.location.isEmpty ? Palette.secondaryText : Palette.text)
                    .lineLimit(1)
                Text(post.dateText.isEmpty ? "No date" : post.dateText)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
            if post.processedAt == nil {
                ProgressView()
                    .accessibilityLabel("Reading photo details")
            }
        }
        .padding(.vertical, 2)
    }
}
