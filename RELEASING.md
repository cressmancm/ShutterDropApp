# Releasing ShutterDrop

Releases go to the App Store, built and uploaded entirely in Xcode. Only the maintainer can make one.

## Once

- **Signing:** `app/Signing.local.xcconfig` with the team ID (see CONTRIBUTING.md). Xcode manages the certificates and profiles.
- **App Store Connect:** the app record exists, named ShutterDrop with the bundle ID `com.chipcressman.shutterdrop`.
- **Privacy policy:** live at https://cressmancm.github.io/ShutterDropApp/privacy/ from `docs/privacy`, with GitHub Pages serving the `docs` folder of `main`.
- **App Privacy label:** Data Not Collected. Private Cloud Compute doesn't change this: the photo goes to Apple to answer the request and isn't stored, and ShutterDrop never receives it. Recheck against Apple's guidance when submitting.
- **Private Cloud Compute:** requested on Apple's [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute/) page; it needs the App Store Small Business Program and fewer than 2 million first-time downloads. Once Apple assigns it to the account, uncomment the two Private Cloud Compute lines in `app/Signing.local.xcconfig` (see the `.example`): they sign with `app/ShutterDrop.entitlements` (`com.apple.developer.private-cloud-compute`) and compile in the code that calls the model. Without the entitlement, calling the model crashes the app, which is why builds leave it out by default. Test with a debug build on an iPhone, TestFlight or ad hoc; those installs don't count toward the limit.

## Each release

1. **Bump the version** in the ShutterDrop target's General tab: Version (`MARKETING_VERSION`, like `1.1`) and Build (`CURRENT_PROJECT_VERSION`, one more than last time).
2. **Commit** as `ShutterDrop <version>`, push, and wait for CI to pass.
3. **Try it on a real iPhone** from a clean install: delete the app, run it from Xcode on the iPhone, and go through onboarding, adding a photo to the album, the post screen, Copy Post, and Open in Instagram. With Private Cloud Compute on, check that a new photo's place, alt text and hashtag ideas come from it (`category:altText` in the log).
4. **Archive:** pick Any iOS Device (arm64) as the destination, then Product › Archive.
5. **Upload:** in the Organizer that opens, select the archive, then Distribute App › App Store Connect › Distribute.
6. **Submit:** in App Store Connect, add the build to the new version, fill in What's New, and Submit for Review.
7. **Tag** the commit it was built from, and push the tag:

   ```bash
   git tag -a v<version> <commit> -m "ShutterDrop <version>"
   git push origin v<version>
   ```
