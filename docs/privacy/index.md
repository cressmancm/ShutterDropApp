---
title: ShutterDrop Privacy Policy
---

# ShutterDrop Privacy Policy

Last updated: November 15, 2026

ShutterDrop collects no data. It has no accounts, analytics, tracking or ads, and it doesn't send your photos or posts to me. The only times a photo leaves your iPhone are if you turn on Private Cloud Compute or Claude, described below.

## On your iPhone

- **Photos:** ShutterDrop reads the photos in your ShutterDrop album, or the ones you choose with the photo picker, to fill in their details. Apple's Vision framework looks at each photo on your iPhone, and if you turn on alt text, Apple Intelligence writes it on your iPhone too. Unless you turn on Private Cloud Compute, photos are never uploaded.
- **Posts:** your captions, hashtags, alt text and the rest of each post are stored only in ShutterDrop on your iPhone. There's no sync, backup or export, and deleting the app deletes them.

## What leaves your iPhone

- **Location Lookups:** when this setting is on, ShutterDrop sends a photo's GPS position to Apple's MapKit service to find a place name. Nothing else about the photo is sent. Apple's handling of that request is covered by Apple's privacy policy. You can turn Location Lookups off in onboarding or in Settings.
- **Private Cloud Compute:** off unless you turn it on in Settings. When it's on, ShutterDrop sends each new photo, with its place name, nearby place names, date and the labels Vision found, to Apple Intelligence on Apple's Private Cloud Compute servers, which recognize the place the photo shows, write its alt text and suggest hashtags. Apple uses this only to answer the request and doesn't store it; see Apple's [Private Cloud Compute](https://security.apple.com/blog/private-cloud-compute/) documentation. ShutterDrop never receives or keeps a copy anywhere else. Turn it off and everything happens on your iPhone again.
- **Claude:** off unless you save your own Anthropic API key and turn it on in Settings. When it's on, ShutterDrop sends each new photo, with its place name, nearby place names, date, camera details and the labels Vision found, to Anthropic's Claude, which names the place the photo shows, writes its alt text and searches the web for hashtags. The request goes directly from your iPhone to Anthropic using your key, so it's covered by the terms you accepted for that key and Anthropic's [privacy policy](https://www.anthropic.com/legal/privacy), and Anthropic bills your account. ShutterDrop keeps the key in your iPhone's Keychain and never sends it, or the photo, to me. Remove the key or turn Claude off and nothing goes to Anthropic.
- **Hashtag search:** when you tap Search Hashtags, best-hashtags.com opens in Safari inside ShutterDrop and receives the search term. That site's own privacy policy applies to your visit.
- **Open in Instagram:** when you tap it, ShutterDrop hands the photo to the Instagram app on your iPhone. Instagram's privacy policy applies from there.

## Permissions

ShutterDrop asks for full access to your photo library so it can read the ShutterDrop album, create it if it's missing, and take photos out of it when you remove them from the queue. You can say no and still choose photos one at a time with the photo picker. ShutterDrop never asks for Location Services.

## Contact

Questions: open an issue at [github.com/cressmancm/ShutterDropApp](https://github.com/cressmancm/ShutterDropApp/issues).
