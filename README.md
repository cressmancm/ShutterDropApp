# ShutterDrop

[![Tests](https://github.com/cressmancm/ShutterDropApp/actions/workflows/tests.yml/badge.svg)](https://github.com/cressmancm/ShutterDropApp/actions/workflows/tests.yml)

**A free iPhone app that turns your photos into Instagram posts that are ready to paste.**

## Why I made this

Every photo I post to Instagram follows the same layout: a caption, where it was taken, the camera and lens, the exposure, the date, a note that it was edited in Lightroom, and a handful of hashtags. Typing all of that out for every post got old fast, and most of it is already sitting inside the photo.

My first version was a [Claude Code](https://claude.com/claude-code) skill on my Mac. It read a ShutterDrop album in Apple Photos, pulled the camera details out of each photo, looked up the place, had Claude write alt text and research hashtags, and wrote everything into a Numbers spreadsheet. It worked, but it lived on my Mac, and I post from my phone.

So I rebuilt it as an iPhone app, again with Claude Code as my partner. This time everything happens on the phone: Apple's Vision framework and the on-device Apple Intelligence model look at the photo, and nothing is uploaded anywhere. It was a chance to learn iOS development and agentic coding while solving a real problem of my own.

ShutterDrop is free and privacy-focused, and it always will be. You can see more of my work at [chipcressman.photo](https://chipcressman.photo).

<!-- Screenshots go here once they're taken on a real iPhone: docs/screenshots/ -->

## What it does

- **Fills in the details.** Camera, lens, ISO, focal length, aperture, shutter speed and date come straight from each photo. Missing readings are left out, never shown as zero.
- **Names the place.** With Location Lookups on, the photo's location becomes a place name like "Zona Romántica, Puerto Vallarta, Jal.", never a street address.
- **Writes alt text on your iPhone.** Apple Intelligence looks at the photo and writes two or three sentences for screen readers. Regenerate it, or edit it, any time.
- **Lays out the post your way.** One post template with `{template tags}` decides the layout of every post. A line whose tags are empty drops out, so a photo with no location simply has no 📍 line.
- **Helps with hashtags.** Search Hashtags opens a hashtag research site inside the app. Paste what you find and ShutterDrop keeps only the #tags. Suggestions come from your own past tags and the place name.
- **One tap to Instagram.** Copy Post puts the finished post on the clipboard. Open in Instagram copies it too, then opens Instagram's new-post screen with the photo already chosen.
- **Keeps a queue.** Add photos to a ShutterDrop album in Photos, or pick them in the app. Mark a post as posted and it moves out of the queue.

## Requirements

- An iPhone with Apple Intelligence: iPhone 15 Pro or later, with Apple Intelligence turned on.
- iOS 27 or later.

ShutterDrop needs Apple Intelligence to write alt text and has no fallback. On an iPhone without it, the app says so and goes no further.

## Security and privacy

- **No analytics, tracking or accounts.** ShutterDrop collects nothing about you or your photos, and reports nothing to anyone, including me.
- **No ads.** None, now or ever.
- **Your photos stay on your iPhone.** Vision and Apple Intelligence run on the device. Photos are never uploaded.
- **Your posts stay on your iPhone too.** There's no sync, backup or export. Deleting the app deletes them.
- **Open source.** Every line of ShutterDrop is in this repository.

### What leaves the iPhone, and when

| Connection | What it sends | When |
| --- | --- | --- |
| Location Lookups (Apple MapKit) | The photo's GPS position, to get a place name | Only when Location Lookups is on. It's a setting, and onboarding asks first. |
| Hashtag search site | The search term you typed | Only when you tap Search Hashtags. The site opens in Safari inside the app. |
| Open in Instagram | The photo, handed to the Instagram app on your iPhone | Only when you tap Open in Instagram. |

### Permissions

| Permission | Why ShutterDrop needs it |
| --- | --- |
| **Full photo library access** | To read the ShutterDrop album, create it if it's missing, and take photos out of it when you remove them from the queue. Optional: without it, you can still add photos one at a time with the photo picker. |

ShutterDrop never asks for Location Services. Place names come from the location already saved in each photo.

The [privacy policy](https://cressmancm.github.io/ShutterDropApp/privacy/) says the same in full.

## How it works

ShutterDrop is a SwiftUI app with no third-party code.

- **Photos** (PhotoKit, ImageIO): reads the ShutterDrop album each time the app opens, and the camera details from each photo's metadata, downloading originals from iCloud when needed.
- **Place names** (MapKit): reverse geocoding plus nearby points of interest, picked in order: an area of interest, a landmark near the photo, the neighborhood, then the city.
- **Seeing the photo** (Vision, Foundation Models): Vision names what's in the photo and reads any text in it; Apple's on-device model writes the alt text from the photo itself.
- **Posts** (SwiftData): each post keeps its details, caption, hashtags and alt text on the device.

| Folder | What's in it |
| --- | --- |
| `app/Sources/ShutterDrop` | The app |
| `app/Tests/ShutterDropTests` | The tests |
| `app/ShutterDrop.xcodeproj` | The Xcode project |
| `docs` | The privacy policy page and screenshots |

Check out [ARCHITECTURE.md](ARCHITECTURE.md) for a map of the codebase.

## Building from source

You'll need a Mac with Xcode 27 or later. Open `app/ShutterDrop.xcodeproj`, pick an iPhone simulator running iOS 27, and run the **ShutterDrop** scheme. To run on your own iPhone, copy `app/Signing.local.xcconfig.example` to `app/Signing.local.xcconfig` and put in your team ID.

To run the tests: Product › Test (⌘U) in Xcode.

[CONTRIBUTING.md](CONTRIBUTING.md) covers the rest, and [RELEASING.md](RELEASING.md) walks through an App Store release.

## Credits

Built with [Claude Code](https://claude.com/claude-code).

## License

ShutterDrop is open source under the MIT license (see [LICENSE](LICENSE)).
