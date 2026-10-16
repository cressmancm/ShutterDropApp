import SafariServices
import SwiftUI
import UIKit

/// Apple's in-app Safari, for the hashtag search page. ShutterDrop can't see
/// what's on the page; the user copies what they want.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Open in Instagram: hands the photo to Instagram's new-post screen the way
/// Meta documents it, as an Instagram-only .igo file. Instagram can't take a
/// caption, so the post is already on the clipboard. When Instagram isn't
/// installed or won't open, the share sheet opens instead.
@MainActor
final class InstagramSharer {
    static let shared = InstagramSharer()
    private var controller: UIDocumentInteractionController?

    /// Instagram resizes larger photos itself.
    private let maxPixelSize = 2160

    func share(imageData: Data) {
        guard let image = PhotoDetailsReader.previewImage(from: imageData, maxPixelSize: maxPixelSize).map(UIImage.init(cgImage:)),
              let jpeg = image.jpegData(compressionQuality: 0.92),
              let host = Self.topViewController()
        else { return }

        // The menu only lists Instagram, and doesn't open at all when
        // Instagram isn't installed.
        let file = URL.temporaryDirectory.appending(path: "ShutterDrop.igo")
        if (try? jpeg.write(to: file, options: .atomic)) != nil {
            let controller = UIDocumentInteractionController(url: file)
            controller.uti = "com.instagram.exclusivegram"
            self.controller = controller
            if controller.presentOpenInMenu(from: host.view.bounds, in: host.view, animated: true) {
                return
            }
        }
        let sheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = host.view
        host.present(sheet, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
