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
                ContentUnavailableView {
                    ProgressView()
                        .controlSize(.large)
                    Text("Getting Ready")
                } description: {
                    Text("Apple Intelligence is still downloading to this iPhone. ShutterDrop will open on its own when it's ready.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
