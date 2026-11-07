# Release readiness checklist

This is an evidence-based checklist, not a claim that the app is ready for public release.

## Automated checks
- [ ] Dart formatting check passes.
- [ ] Flutter static analysis passes on the latest main commit.
- [ ] Flutter unit and widget tests pass on the latest main commit.
- [ ] Android debug APK artifact is available for QA.
- [ ] Signed release APK is built from protected signing secrets and its signature is verified.

## Client-only AI and privacy
- [ ] Confirm there is no backend, server endpoint, server SDK, or compile-time provider key in the release build.
- [ ] Confirm a user can save, update, reveal/hide, and delete their own API key in settings.
- [ ] Verify the key is stored using Android Keystore-backed secure storage and never appears in logs or crash reports.
- [ ] Test direct HTTPS requests to each advertised provider and supported model.
- [ ] Test invalid key (401/403), rate limit (429), provider outage (5xx), timeout, malformed response, offline fallback, and retry behavior.
- [ ] Confirm the app sends only the question, selected stage, and selected goal to the configured provider.
- [ ] Publish a privacy policy explaining that provider processing and retention are governed by the provider's terms.
- [ ] Explain that users are responsible for API usage charges; recommend provider-side spending limits and alerts.
- [ ] Review privacy and child-safety obligations for the intended release countries and age groups.

## Product and local data
- [ ] Test on a real Android phone and multiple screen sizes.
- [ ] Confirm tasks, notes, exam records, and preferences survive force-close and device restart.
- [ ] Confirm deleting study data does not unexpectedly delete the separate AI key.
- [ ] Confirm deleting the AI key does not delete study data.
- [ ] Verify offline functionality with airplane mode enabled.
- [ ] Review Persian content and educational guidance with a qualified advisor.

## Android and Cafe Bazaar
- [ ] Verify the chosen application ID is not already used by another published app.
- [ ] Add final app icon, Persian app label, version code, and version name.
- [ ] Confirm the release manifest contains only required permissions, including internet access.
- [ ] Configure release signing through GitHub secrets; never commit keystores or passwords.
- [ ] Build and verify the signed release APK/AAB according to current Bazaar submission requirements.
- [ ] Install the signed release build on a real device and test online/offline transitions.
- [ ] Prepare store screenshots, descriptions, support contact, and privacy-policy URL.
- [ ] Submit only after all checks above are completed.

The CI debug APK is for testing, not a signed production release.
