# ShutterDrop App Store listing

What goes into App Store Connect for version 1.0. Saved there, not submitted. Nothing goes to App Review until the build is uploaded and Add for Review is pressed.

## App Information

| Field | Value |
| --- | --- |
| Name | ShutterDrop |
| Subtitle | Photo posts, ready to paste |
| Primary category | Photo & Video |
| Secondary category | Productivity |
| Content rights | No third-party content |
| Age rating | See the questionnaire below |

### Age rating questionnaire

Every answer is None or No, for a 4+ rating. **Unrestricted Web Access** is No because Search Hashtags opens only best-hashtags.com; the address can't be changed in Settings.

## Pricing and Availability

- **Price:** Free (USD 0.00).
- **Availability:** all countries and regions.
- **Apple silicon Macs:** off. ShutterDrop is an iPhone app, portrait only, and is untested on a Mac.
- **Apple Vision Pro:** off, for the same reason.

## App Privacy

- **Privacy policy URL:** https://cressmancm.github.io/ShutterDropApp/privacy/
- **Data collection:** Data Not Collected. MapKit lookups and Private Cloud Compute requests go to Apple only to answer the request in real time and aren't stored, and ShutterDrop never receives them.

## App Accessibility

Claim only what's been checked on a real iPhone. For now:

- **Dark Interface:** yes. The app is always dark.
- **Sufficient Contrast:** yes. Every text color passes WCAG AA on its background.
- **VoiceOver, Voice Control, Larger Text, Differentiate Without Color, Reduced Motion:** leave until tested on a device.

## Version 1.0

**Promotional text** (163 of 170):

> Add photos to an album and ShutterDrop lays out each post with the camera, lens, exposure, date and place, ready to paste. Free, with no ads, accounts or tracking.

**Description:**

> ShutterDrop turns your photos into Instagram posts that are ready to paste.
>
> Every photo already knows its camera, lens, exposure, date and place. ShutterDrop reads those details and lays them out the way you post, so all you write is the caption.
>
> FILLS IN THE DETAILS
> Camera, lens, ISO, focal length, aperture, shutter speed and date come straight from each photo. Missing readings are left out, never shown as zero.
>
> NAMES THE PLACE
> With Location Lookups on, the photo's location becomes a place name like "West Point Lighthouse, Seattle, WA", never a street address.
>
> HELPS WITH ALT TEXT
> With Apple Intelligence, ShutterDrop describes each photo for screen readers, right on your iPhone. Edit it, or write your own.
>
> GOES FURTHER WITH PRIVATE CLOUD COMPUTE
> If you allow it, Apple's larger model recognizes what the photo shows, writes richer alt text and suggests hashtags. It's off until you turn it on.
>
> LAYS OUT THE POST YOUR WAY
> One template with tags like {location} and {exposure} sets the layout of every post. A line with nothing to show drops out.
>
> HELPS WITH HASHTAGS
> Search a hashtag site inside the app and paste what you find. ShutterDrop keeps only the #tags.
>
> ONE TAP TO INSTAGRAM
> Copy Post puts the finished post on the clipboard. Open in Instagram copies it too, then opens Instagram with the photo already chosen.
>
> KEEPS A QUEUE
> Add photos to a ShutterDrop album in Photos, or pick them in the app. Mark a post as posted and it leaves the queue.
>
> FREE AND PRIVATE
> No ads, accounts, analytics or tracking. Your photos and posts stay on your iPhone unless you turn on Private Cloud Compute. ShutterDrop is open source.
>
> Requires iOS 27. Alt text written by Apple Intelligence needs iPhone 15 Pro or later.

**Keywords** (99 of 100): `caption,exif,metadata,camera,lens,exposure,hashtag,alt text,photographer,post,location,iso,aperture`

Words already in the name, subtitle or category aren't repeated, and other apps' names are left out, as Apple's guidelines ask.

| Field | Value |
| --- | --- |
| Support URL | https://github.com/cressmancm/ShutterDropApp/issues |
| Marketing URL | (blank) |
| Copyright | 2026 Chip Cressman |
| Release | Manually release this version |

### App Review information

- **Sign-in required:** no.
- **Contact:** your name, phone and email. You fill these in.
- **Notes:**

> ShutterDrop has no accounts or sign-in. To try it, allow photo access during onboarding, add a photo with camera details and a location to the ShutterDrop album in Photos (the app creates the album), and open ShutterDrop again. Or tap + to choose a photo. Alt text needs Apple Intelligence. Private Cloud Compute is off by default; turn it on in Settings. Open in Instagram needs the Instagram app installed.

## Later

- **Screenshots:** 6.9-inch iPhone screenshots, taken on a real iPhone with real photos.
- **Build:** uploaded from Xcode when it's time to release (see RELEASING.md). Before then, add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` to the target so uploads skip the export compliance question.
