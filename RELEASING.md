# Releasing ShutterDrop

Releases go to the App Store, built and uploaded entirely in Xcode. Only the maintainer can make one.

## Once

- **Signing:** `app/Signing.local.xcconfig` with the team ID (see CONTRIBUTING.md). Xcode manages the certificates and profiles.
- **App Store Connect:** the app record exists, named ShutterDrop with the bundle ID `com.chipcressman.shutterdrop`.
- **Privacy policy:** live at https://cressmancm.github.io/ShutterDropApp/privacy/ from `docs/privacy`, with GitHub Pages serving the `docs` folder of `main`.
- **App Privacy label:** Data Not Collected.

## Each release

1. **Bump the version** in the ShutterDrop target's General tab: Version (`MARKETING_VERSION`, like `1.1`) and Build (`CURRENT_PROJECT_VERSION`, one more than last time).
2. **Commit** as `ShutterDrop <version>`, push, and wait for CI to pass.
3. **Try it on a real iPhone** from a clean install: delete the app, run it from Xcode on the iPhone, and go through onboarding, adding a photo to the album, the post screen, Copy Post, and Open in Instagram.
4. **Archive:** pick Any iOS Device (arm64) as the destination, then Product › Archive.
5. **Upload:** in the Organizer that opens, select the archive, then Distribute App › App Store Connect › Distribute.
6. **Submit:** in App Store Connect, add the build to the new version, fill in What's New, and Submit for Review.
7. **Tag** the commit it was built from, and push the tag:

   ```bash
   git tag -a v<version> <commit> -m "ShutterDrop <version>"
   git push origin v<version>
   ```
