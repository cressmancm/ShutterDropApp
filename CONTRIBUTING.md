# Working on ShutterDrop

Thanks for looking. This covers building and running ShutterDrop, the settings and launch arguments that help while you work, and the parts that are awkward to try by hand. For how the code fits together, see [ARCHITECTURE.md](ARCHITECTURE.md).

## What you need

- A Mac with Xcode 27 or later. [`.xcode-version`](.xcode-version) holds the minimum, and CI checks it.
- An iPhone simulator running iOS 27. Xcode › Settings › Components installs the runtime.
- For the parts that need real hardware (alt text quality, Open in Instagram), an iPhone 15 Pro or later on iOS 27 with Apple Intelligence on.

## In Xcode

Open `app/ShutterDrop.xcodeproj` and use the **ShutterDrop** scheme: Run (⌘R) builds and opens the app, Test (⌘U) runs the tests.

**Signing.** Simulator builds need no team. To run on an iPhone or archive for the App Store, copy `app/Signing.local.xcconfig.example` to `app/Signing.local.xcconfig` (git ignores it) and put in your team ID. Xcode signs with your Apple Development certificate and makes the provisioning profile itself.

## Launch arguments for the simulator

Debug builds read these; release builds ignore them. Add them in the scheme's Run › Arguments, or pass them to `xcrun simctl launch`.

| Argument | What it does |
| --- | --- |
| `-skipIntelligenceCheck` | Shows the app even where Apple Intelligence can't run |
| `-intelligenceState downloading` | Shows that Apple Intelligence screen (`unsupported`, `off` or `downloading`) whatever the device says |
| `-sampleData` | Fills an empty store with four example posts |
| `-onboardingDone YES` | Skips onboarding (it sets the setting itself) |
| `-startTab posted` or `-startTab settings` | Opens on that tab |
| `-openFirstPost` | Opens the newest post in the queue |

For example, to see the post screen with an example post:

```bash
xcrun simctl launch booted com.chipcressman.shutterdrop -skipIntelligenceCheck -sampleData -onboardingDone YES -openFirstPost
```

## Where ShutterDrop keeps things

- **Posts:** a SwiftData store in the app's Application Support folder.
- **Photos chosen with the picker:** copies in Application Support › Picked Photos, deleted when the post is removed.
- **Settings:** `UserDefaults`, under the keys in `AppSettings`.

Deleting the app removes all of it.

## Trying the hard-to-reach parts

- **Onboarding again:** delete the app, or launch with `-onboardingDone NO`.
- **The photo prompt again:** delete the app. In the simulator, if the prompt keeps reappearing after a fresh install, erase the simulator (Device › Erase All Content and Settings); its permission state can outlive the app.
- **The Apple Intelligence screens:** on a real iPhone, turn Apple Intelligence off in Settings to see the "Turn On" screen. To see any of the three screens in the simulator, launch with `-intelligenceState unsupported`, `off` or `downloading`.
- **Album sync:** add or remove photos from the ShutterDrop album in Photos, then bring ShutterDrop to the front or pull down on the queue.
- **Import:** export ShutterDrop.numbers as CSV (File › Export To › CSV in Numbers), put it in iCloud Drive, and use Settings › Import from CSV. Rows match photos by filename and date taken.
- **Open in Instagram:** needs a real iPhone with Instagram installed. Without Instagram, the share sheet opens instead.

## Tests

The tests cover the template engine, detail formatting, hashtags, place name rules and CSV parsing. They're Swift Testing suites and run hosted in the app, as Xcode runs any app's tests.
