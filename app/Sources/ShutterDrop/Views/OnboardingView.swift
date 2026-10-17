import SwiftData
import SwiftUI

/// First launch: what ShutterDrop does, then photo access and Location Lookups,
/// each asked for when it's explained.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, photos, location, ready
    }

    @Environment(\.modelContext) private var context
    @Environment(Intake.self) private var intake
    @AppStorage(AppSettings.onboardingDone) private var onboardingDone = false
    @AppStorage(AppSettings.locationLookups) private var lookups = true
    @State private var step = Step.welcome

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    switch step {
                    case .welcome: welcome
                    case .photos: photos
                    case .location: location
                    case .ready: ready
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                PageDots(count: Step.allCases.count, current: step.rawValue)
                    .padding(.bottom, 8)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.background)
        .animation(.default, value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 28) {
            Header(systemImage: "camera.aperture", title: "ShutterDrop", message: "Turn your photos into Instagram posts that are ready to paste.", large: true)
            VStack(alignment: .leading, spacing: 22) {
                Feature(systemImage: "photo", title: "Fills in the details", message: "Camera, lens, exposure, date and place, read from each photo.")
                Feature(systemImage: "sparkles", title: "Writes alt text on your iPhone", message: "Apple Intelligence describes each photo. Nothing is uploaded.")
                Feature(systemImage: "doc.on.doc", title: "Copy, paste, post", message: "Your post is laid out and one tap away from Instagram.")
            }
        }
    }

    private var photos: some View {
        VStack(spacing: 24) {
            Header(systemImage: "photo.stack", title: "Your Photos", message: "Add photos to the ShutterDrop album in Photos, and they show up in your queue.")
            Checklist(items: [
                ("plus", "Creates the ShutterDrop album if you don't have one"),
                ("info.circle", "Reads each photo's camera details and location"),
                ("minus", "Takes a photo out of the album when you remove it"),
            ])
            Label("Your photos never leave this iPhone.", systemImage: "lock")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private var location: some View {
        VStack(spacing: 24) {
            Header(systemImage: "mappin.and.ellipse", title: "Add Place Names", message: "ShutterDrop can turn a photo's location into a place name for your post.")
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .foregroundStyle(Palette.secondaryText)
                Text("20.6° N, 105.2° W \(Text("becomes").foregroundStyle(Palette.secondaryText)) Zona Romántica, Puerto Vallarta, Jal.")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            Checklist(items: [
                ("arrow.right", "Sends only the photo's location to Apple to look up the name"),
                ("checkmark.circle", "Uses the location already saved in each photo, so no Location Services prompt"),
                ("gearshape", "Change it anytime in Settings › Location Lookups"),
            ])
        }
    }

    private var ready: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Palette.accent)
                .padding(.top, 60)
            Text("You're Ready")
                .font(.title.bold())
            Text(intake.library.hasFullAccess
                 ? "Your ShutterDrop album is in Photos. Add photos to it from the Photos app, or tap + to choose some here."
                 : "Tap + to choose photos. To use the ShutterDrop album instead, allow photo access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    // MARK: Buttons

    @ViewBuilder
    private var buttons: some View {
        switch step {
        case .welcome:
            PrimaryButton("Continue") { step = .photos }
        case .photos:
            PrimaryButton("Allow Photo Access") {
                Task {
                    await intake.library.requestAccess()
                    _ = try? await intake.library.album()
                    step = .location
                }
            }
            Button("Not Now") { step = .location }
                .frame(minHeight: 44)
            Text("Without access, you can still choose photos one at a time with the + button.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
        case .location:
            PrimaryButton("Turn On Location Lookups") {
                lookups = true
                step = .ready
            }
            Button("Not Now") {
                lookups = false
                step = .ready
            }
            .frame(minHeight: 44)
        case .ready:
            PrimaryButton("Get Started") {
                onboardingDone = true
                Task { await intake.syncAlbum(in: context) }
            }
        }
    }
}

// MARK: Pieces

private struct Header: View {
    let systemImage: String
    let title: String
    let message: String
    var large = false

    var body: some View {
        VStack(spacing: 16) {
            if large {
                AppLogo()
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 80, height: 80)
                    .background(Palette.accent.opacity(0.16), in: .rect(cornerRadius: 20))
            }
            Text(title)
                .font(large ? .largeTitle.bold() : .title.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.secondaryText)
        }
    }
}

private struct Feature: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
    }
}

private struct Checklist: View {
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider().overlay(Palette.raised).padding(.leading, 40) }
                HStack(spacing: 14) {
                    Image(systemName: item.0)
                        .foregroundStyle(Palette.accent)
                        .frame(width: 24)
                    Text(item.1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Palette.accent : Palette.raised)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(Palette.onAccent)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }
}
