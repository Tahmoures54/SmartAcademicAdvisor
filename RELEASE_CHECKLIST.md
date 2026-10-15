# Release readiness checklist

This is a development checklist, not a claim that the app is ready for public release.

## Automated checks
- [ ] Flutter analyze passes on the latest main commit.
- [ ] Flutter widget tests pass on the latest main commit.
- [ ] Android debug APK build succeeds and the workflow artifact is available.
- [ ] Backend unit tests pass.

## Product and privacy
- [ ] Test the app on a real Android phone and multiple screen sizes.
- [ ] Confirm task and note data survive force-close and device restart.
- [ ] Confirm deleting local data removes saved preferences and notes.
- [ ] Decide whether AI requests are enabled for the first public release.
- [ ] If AI is enabled, deploy backend over HTTPS, configure the provider key only on the server, and test provider failure, timeout, and quota behavior.
- [ ] Publish a privacy policy appropriate for student/minor users and explain when questions leave the device.
- [ ] Review the Persian content and educational guidance with a qualified advisor.

## Android and Cafe Bazaar
- [ ] Choose and permanently confirm the Android application ID/package name.
- [ ] Add final app icon, app name, version code, and version name.
- [ ] Confirm the required Android permissions are minimal.
- [ ] Configure release signing securely; do not commit signing keys or passwords.
- [ ] Build a release APK/AAB as required by the current Bazaar submission rules.
- [ ] Install and test the signed release build on a real device.
- [ ] Prepare store screenshots, short/long descriptions, support contact, and privacy-policy URL.
- [ ] Submit to Bazaar only after all checks above are completed.

The current CI artifact is a **debug APK for testing**, not a signed release package.
