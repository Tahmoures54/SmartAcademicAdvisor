# Release readiness checklist

This is an evidence-based checklist, not a claim that the app is ready for public release.

## Automated checks
- [ ] Flutter format, analyze, and widget tests pass on the latest main commit.
- [ ] Backend lint, compile, and regression tests pass.
- [ ] Backend Docker image builds successfully in CI.
- [ ] Debug APK artifact is available for QA.
- [ ] Signed release APK is built from protected signing secrets and its signature is verified.

## Backend and AI
- [ ] Deploy the backend to an HTTPS host and verify both `/health` and `/ready`.
- [ ] Keep `AI_API_KEY` only in the hosting provider's secret environment.
- [ ] Set provider-side hard spending limits and usage alerts.
- [ ] Test valid response, missing key, provider 429/5xx, timeout, malformed response, and cold-start behavior.
- [ ] Replace the in-process throttle with shared rate limiting or an authenticated access design before unrestricted public launch.
- [ ] Set GitHub Actions variable `ADVISOR_API_BASE_URL` to the verified backend URL.

## Product and privacy
- [ ] Test on a real Android phone and multiple screen sizes.
- [ ] Confirm tasks, notes, exam records, and preferences survive force-close and device restart.
- [ ] Confirm the user can delete locally stored data.
- [ ] Decide whether live AI is enabled for the first public release.
- [ ] Publish a privacy policy URL and explain when questions leave the device and are sent to the backend/provider.
- [ ] Review Persian content and educational guidance with a qualified advisor.
- [ ] Review privacy and child-safety obligations for the intended release countries and age groups.

## Android and Cafe Bazaar
- [ ] Verify the chosen application ID is not already used by another published app.
- [ ] Add final app icon, Persian app label, version code, and version name.
- [ ] Confirm the release manifest contains only required permissions, including internet access for the API.
- [ ] Configure release signing through GitHub secrets; never commit keystores or passwords.
- [ ] Build and verify the signed release APK/AAB according to the current Bazaar submission requirements.
- [ ] Install the signed release build on a real device and test offline/online transitions.
- [ ] Prepare store screenshots, short/long descriptions, support contact, and privacy-policy URL.
- [ ] Submit to Bazaar only after all checks above are completed.

The current CI artifact named `smart-academic-advisor-debug-apk` is a debug build for testing, not a signed production release.
