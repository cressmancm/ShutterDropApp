# Working on ShutterDrop

Thanks for looking. This covers building and running ShutterDrop, the settings and launch arguments that help while you work, and the parts that are awkward to try by hand. For how the code fits together, see [ARCHITECTURE.md](ARCHITECTURE.md).

## What you need

- A Mac with Xcode 27 or later. [`.xcode-version`](.xcode-version) holds the minimum, and CI checks it.
- An iPhone simulator running iOS 27. Xcode › Settings › Components installs the runtime.
- For the parts that need real hardware (alt text quality, Open in Instagram), an iPhone on iOS 27; for alt text, an iPhone 15 Pro or later with Apple Intelligence on.

## In Xcode

Open `ShutterDrop.xcodeproj` and use the **ShutterDrop** scheme: Run (⌘R) builds and opens the app, Test (⌘U) runs the unit and UI tests.

**Signing.** Signing is automatic, with the maintainer's team set in the project. Simulator builds work with any team. To run on your own iPhone, pick your team in the ShutterDrop target's Signing & Capabilities, and change the bundle ID if Xcode asks; leave both out of pull requests. Xcode signs with your Apple Development certificate and makes the provisioning profile itself.

## Launch arguments for the simulator

Debug builds read these; release builds ignore them. Add them in the scheme's Run › Arguments, or pass them to `xcrun simctl launch`.

| Argument | What it does |
| --- | --- |
| `-intelligenceState off` | Acts as if Apple Intelligence were `ready`, `unsupported`, `off` or `downloading`, whatever the device says |
| `-onboardingStep altText` | Starts onboarding at `photos`, `location`, `altText` or `ready` |
| `-sampleData` | Fills an empty store with four example posts |
| `-onboardingDone YES` | Skips onboarding (it sets the setting itself) |
| `-startTab posted` or `-startTab settings` | Opens on that tab |
| `-openFirstPost` | Opens the newest post in the queue |
| `-openDebugTools` | Opens Settings › Debug Tools (use with `-startTab settings`) |
| `-fillAlbum 20` | Adds that many of the library's newest photos to the ShutterDrop album before the first sync (needs full photo access) |

For example, to see the post screen with an example post:

```bash
xcrun simctl launch booted com.chipcressman.shutterdrop -sampleData -onboardingDone YES -openFirstPost
```

## Debug Tools

Debug builds add **Settings › Debug Tools**, for testing and reviewing without leaving the app. Release builds compile none of it in.

- **Apple Intelligence:** force Ready, Not Supported, Turned Off or Downloading, or follow the device. It changes what the Alt Text setting, the post screen and onboarding offer.
- **Preview Onboarding:** onboarding on its own, with a Close button, as it looks in the forced state. It doesn't ask for access or save answers.
- **Restart Onboarding:** runs the real onboarding again.
- **Posts:** add sample posts, mark everything as not posted, read every photo again, or delete all posts to see the empty queue.
- **Photos:** the current access, asking for it if it hasn't been asked, iOS Settings, syncing the album now, and adding the library's newest 10, 50 or 150 photos to the album to try a big one.
- **Reset ShutterDrop's Settings:** the default template, search site, Location Lookups and alt text setting, and no forced state.

## Logs

ShutterDrop logs with `Logger` under the subsystem `com.chipcressman.shutterdrop`, in the categories `intake`, `photos`, `location`, `altText` and `sharing`. Album syncs, each photo read (with timings), MapKit lookups and throttling, alt text and errors all show up there.

To see only ShutterDrop's lines in Xcode's console, filter on `subsystem:com.chipcressman.shutterdrop`, or a category with `category:location`. Filenames, places and alt text are logged as private, so they show as `<private>` outside a debugger.

## Where ShutterDrop keeps things

- **Posts:** a SwiftData store in the app's Application Support folder.
- **Photos chosen with the picker:** copies in Application Support › Picked Photos, deleted when the post is removed.
- **Settings:** `UserDefaults`, under the keys in `AppSettings`.

Deleting the app removes all of it.

## Trying the hard-to-reach parts

- **Onboarding again:** delete the app, or launch with `-onboardingDone NO`.
- **The photo prompt again:** delete the app. In the simulator, if the prompt keeps reappearing after a fresh install, erase the simulator (Device › Erase All Content and Settings); its permission state can outlive the app.
- **Without Apple Intelligence:** force a state in Debug Tools, or launch with `-intelligenceState unsupported`, `off` or `downloading`, then look at the onboarding Alt Text step, Settings › Alt Text and a post's Alt Text section. On a real iPhone, turning Apple Intelligence off in iOS Settings does the same for `off`.
- **Album sync:** add or remove photos from the ShutterDrop album in Photos, then bring ShutterDrop to the front or pull down on the queue.
- **A big album:** Debug Tools › Add Newest Photos to the Album, or launch with `-fillAlbum 150`. The queue's subtitle counts through the photos as they're read, and the `location` log shows the lookups spaced out.
- **Private Cloud Compute:** needs the Private Cloud Compute entitlement on the developer account, turned on in the project's build settings (see RELEASING.md). Builds without it leave the Settings section and every call out, since calling the model without the entitlement crashes the app. With it, a failed request (offline, over the limit) is logged under `category:altText` and ShutterDrop falls back to the on-device path. To try the daily limit, use the scheme's Run › Options › Simulated Apple Foundation Models Availability.
- **Place names:** `LocationNamer` matches Vision labels like lighthouse, waterfall and bridge to nearby place names. The `location` log says when a name came from that match.
- **Open in Instagram:** needs a real iPhone with Instagram installed. Without Instagram, the share sheet opens instead.

## Tests

The tests cover the template engine, detail formatting, hashtags and place name rules. They're Swift Testing suites and run hosted in the app, as Xcode runs any app's tests.
