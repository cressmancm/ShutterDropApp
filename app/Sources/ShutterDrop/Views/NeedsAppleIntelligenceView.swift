import SwiftUI

/// Shown instead of the app when Apple Intelligence can't run. ShutterDrop
/// needs it to write alt text and has no fallback.
struct NeedsAppleIntelligenceView: View {
    let state: AppleIntelligence
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            switch state {
            case .unsupportedDevice:
                ContentUnavailableView(
                    "This iPhone Isn't Supported",
                    systemImage: "iphone",
                    description: Text("ShutterDrop uses Apple Intelligence, which needs iPhone 15 Pro or later.")
                )
            case .turnedOff:
                ContentUnavailableView {
                    Label("Turn On Apple Intelligence", systemImage: "sparkles")
                } description: {
                    Text("ShutterDrop writes alt text with Apple Intelligence. Turn it on in Settings › Apple Intelligence & Siri.")
                } actions: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }
            case .downloading, .ready:
                // The download is the iPhone's, not ShutterDrop's, so no
                // progress indicator: ShutterDrop can't show or speed it up.
                ContentUnavailableView {
                    VStack(spacing: 16) {
                        AppLogo()
                        Text("Waiting for Apple Intelligence")
                            .font(.title2.bold())
                    }
                } description: {
                    Text("Your iPhone is still downloading Apple Intelligence. ShutterDrop opens on its own once that's done.\n\nYou can check on it in Settings › Apple Intelligence & Siri.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
