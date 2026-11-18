<p align="center"><img src="docs/logo.svg" width="120" alt=""></p>

# ShutterDrop

[![Tests](https://github.com/cressmancm/ShutterDropApp/actions/workflows/tests.yml/badge.svg)](https://github.com/cressmancm/ShutterDropApp/actions/workflows/tests.yml)

**An iPhone app that turns your photos into Instagram posts that are ready to paste. Free and open source.**

<!-- Screenshots go here once they're taken on a real iPhone: docs/screenshots/ -->

## How it works

ShutterDrop reads the camera details already saved in each photo, names the place it was taken, and lays everything out as a post you can paste into Instagram.

1. **Add photos.** Put them in a ShutterDrop album in Photos, or pick them in the app.
2. **Check the post.** ShutterDrop fills in the camera, lens, exposure, date, and place. You add the caption, alt text, and hashtags, with help if you want it.
3. **Post it.** Copy Post puts the finished post on the clipboard. Open in Instagram copies it too, then opens Instagram's new-post screen with the photo already chosen.
4. **Mark it as posted.** The post moves out of the queue.

## Good to know

- One post template with `{template tags}` sets the layout of every post. A line with nothing to fill in is left out, so a photo with no location has no 📍 line.
- With Location Lookups on, a photo's location becomes a place name like "West Point Lighthouse, Seattle, WA". ShutterDrop doesn't show street addresses.
- Alt text is optional. Apple Intelligence can write it on your iPhone, or you can write your own.
- Private Cloud Compute and Claude can recognize the place in a photo, write richer alt text, and suggest hashtags. Both are off until you turn them on.
- Claude needs your own Anthropic API key, and Anthropic bills your account.
- Search Hashtags opens best-hashtags.com inside the app. Paste what you find and ShutterDrop keeps only the #tags.

## Why I made this

Every photo I post to Instagram follows the same layout: a caption, where it was taken, the camera and lens, the exposure, the date, a note that it was edited in Lightroom, and a handful of hashtags. Typing all of that out for every post got old fast, and most of it is already sitting inside the photo.

My first version was a [Claude Code](https://claude.com/claude-code) skill on my Mac. It read a ShutterDrop album in Apple Photos, pulled the camera details out of each photo, looked up the place, had Claude write alt text and research hashtags, and wrote everything into a Numbers spreadsheet. It worked, but it lived on my Mac, and I post from my phone.

So I rebuilt it as an iPhone app, again with Claude Code as my partner. It was a chance to learn iOS development and agentic coding while solving a real problem of my own.

I'm Chip Cressman, an engineering leader in Seattle and a lifelong photographer. More of my work is at [chipcressman.com](https://chipcressman.com) and [chipcressman.photo](https://chipcressman.photo).

## Privacy

I care a lot about privacy, and I build everything with that in mind. ShutterDrop has no analytics, no tracking, no ads, and no account.

Your photos stay on your iPhone unless you choose otherwise. Vision and Apple Intelligence run on the device. A photo is sent off the phone only if you turn on Private Cloud Compute, which sends it to Apple for that one request without storing it, or Claude, which sends it to Anthropic under your own API key.

Your posts are stored only on your iPhone. There's no sync, backup, or export, so deleting the app deletes them.

The code is all here if you want to check for yourself, and the [privacy policy](https://cressmancm.github.io/ShutterDropApp/privacy/) says the same in full.

### What leaves the iPhone, and when

| Connection | What it sends | When |
| --- | --- | --- |
| Location Lookups (Apple MapKit) | The photo's GPS position, to get a place name | Only when Location Lookups is on. It's a setting, and onboarding asks first. |
| Claude (Anthropic) | Each new photo, with its place names, nearby places, camera details and Vision's labels | Only after you save your own API key and turn on Claude in Settings. |
| Hashtag search (best-hashtags.com) | The search term you typed | Only when you tap Search Hashtags. The site opens in Safari inside the app. |
| Open in Instagram | The photo, handed to the Instagram app on your iPhone | Only when you tap Open in Instagram. |

### Permissions

| Permission | Why ShutterDrop needs it |
| --- | --- |
| **Full photo library access** | To read the ShutterDrop album, create it if it's missing, and take photos out of it when you remove them from the queue. Optional: without it, you can still add photos one at a time with the photo picker. |

ShutterDrop doesn't ask for Location Services. Place names come from the location already saved in each photo.

## Requirements

- An iPhone with iOS 27 or later.
- For alt text written by Apple Intelligence: iPhone 15 Pro or later, with Apple Intelligence turned on.
- For Private Cloud Compute: the same, plus a connection. Each person gets a daily limit, higher with iCloud+.
- For Claude: your own Anthropic API key with credit, and a connection. Any iOS 27 iPhone works.

## Support

If something isn't working, please let me know by [opening an issue](../../issues). It helps to include your iPhone model, your iOS version, and any other helpful information.

## Under the hood

ShutterDrop is a SwiftUI app with no third-party code.

- **Photos** (PhotoKit, ImageIO): reads the ShutterDrop album each time the app opens, and the camera details from each photo's metadata, downloading originals from iCloud when needed. Readings a photo doesn't have are left out, not shown as zero.
- **Place names** (MapKit, Vision): reverse geocoding plus nearby points of interest, picked in order: a nearby place whose name matches what Vision sees (West Point Lighthouse for a lighthouse), a named place like Pike Place Market, the neighborhood, a landmark near the photo, then the city.
- **Seeing the photo** (Vision, Foundation Models): Vision names what's in the photo and reads any text in it. Apple's on-device model writes two or three sentences of alt text from the photo itself.
- **Private Cloud Compute** (Foundation Models): when allowed, Apple's server model gets the photo, the nearby places and the light, picks the place it shows, and writes alt text and hashtag ideas as structured output. If it can't run, the on-device path takes over.
- **Claude** (URLSession, the Messages API): with your own key, kept in the Keychain, Claude Sonnet 5.5 gets the photo and its details, searches the web for hashtags, and answers with one strict tool call holding the place, alt text and five hashtags. It goes first when it's on. If it can't run, Private Cloud Compute or the on-device path takes over.
- **The light** (no lookup): the sun's height and direction from the photo's time and GPS position tell golden hour, blue hour and midday apart, for alt text and hashtags.
- **Hashtag suggestions**: from the place, what's in the photo, the region, golden or blue hour, and your own past tags.
- **Posts** (SwiftData): each post keeps its details, caption, hashtags and alt text on the device.

| Folder | What's in it |
| --- | --- |
| `ShutterDrop` | The app |
| `ShutterDropTests` | The unit tests |
| `ShutterDropUITests` | The UI tests |
| `ShutterDrop.xcodeproj` | The Xcode project |
| `docs` | The privacy policy page and screenshots |

Check out [ARCHITECTURE.md](ARCHITECTURE.md) for a map of the codebase.

## Building from source

You need a Mac with Xcode 27 or later. Open `ShutterDrop.xcodeproj`, pick an iPhone simulator running iOS 27, and run the **ShutterDrop** scheme. To run on your own iPhone, pick your team in the ShutterDrop target's Signing & Capabilities.

To run the tests: Product › Test (⌘U) in Xcode.

[CONTRIBUTING.md](CONTRIBUTING.md) covers the rest, and [RELEASING.md](RELEASING.md) walks through an App Store release.

## Built with

Swift, SwiftUI, PhotoKit, Vision, MapKit, Foundation Models, SwiftData, and [Claude Code](https://claude.com/claude-code).

## License

ShutterDrop is open source under the MIT license (see [LICENSE](LICENSE)).
