#!/usr/bin/env python3
"""Apply stable Android application metadata and release signing configuration."""
from __future__ import annotations

import re
from pathlib import Path

APPLICATION_ID = "com.tahmoures54.smartacademicadvisor"
APP_LABEL = "همراه تحصیلی"


def main() -> None:
    app_gradle = Path("android/app/build.gradle.kts")
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not app_gradle.is_file() or not manifest.is_file():
        raise SystemExit("Android scaffold is missing; run flutter create --platforms=android . first.")

    gradle_text = app_gradle.read_text(encoding="utf-8")
    gradle_text, namespace_count = re.subn(
        r'(?m)^\s*namespace\s*=\s*"[^"]+"',
        f'    namespace = "{APPLICATION_ID}"',
        gradle_text,
        count=1,
    )
    gradle_text, app_id_count = re.subn(
        r'(?m)^\s*applicationId\s*=\s*"[^"]+"',
        f'        applicationId = "{APPLICATION_ID}"',
        gradle_text,
        count=1,
    )
    if namespace_count != 1 or app_id_count != 1:
        raise SystemExit("Could not safely locate Android namespace/applicationId in Gradle file.")

    if 'create("release")' not in gradle_text:
        signing_block = '''
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "release-keystore.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

'''
        marker = re.search(r'(?m)^\s*buildTypes\s*\{', gradle_text)
        if not marker:
            raise SystemExit("Could not locate buildTypes block in Gradle file.")
        gradle_text = gradle_text[:marker.start()] + signing_block + gradle_text[marker.start():]

    # Replace Flutter's generated debug signing on release builds.
    gradle_text = re.sub(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("release")',
        gradle_text,
    )
    if 'signingConfig = signingConfigs.getByName("release")' not in gradle_text:
        release_block = re.search(r'(?s)buildTypes\s*\{.*?release\s*\{', gradle_text)
        if not release_block:
            raise SystemExit("Could not locate release build type for signing.")
        insert_at = release_block.end()
        gradle_text = (
            gradle_text[:insert_at]
            + '\n            signingConfig = signingConfigs.getByName("release")'
            + gradle_text[insert_at:]
        )

    app_gradle.write_text(gradle_text, encoding="utf-8")

    manifest_text = manifest.read_text(encoding="utf-8")
    manifest_text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', manifest_text, count=1)
    # Secure-storage encryption keys must not be restored independently of
    # the Android Keystore. This app intentionally keeps its data on-device.
    if re.search(r'android:allowBackup="[^"]*"', manifest_text):
        manifest_text = re.sub(
            r'android:allowBackup="[^"]*"',
            'android:allowBackup="false"',
            manifest_text,
            count=1,
        )
    else:
        manifest_text = re.sub(
            r'(<application\b)',
            r'\1 android:allowBackup="false"',
            manifest_text,
            count=1,
        )
    if "android.permission.INTERNET" not in manifest_text:
        manifest_text = manifest_text.replace(
            "<manifest ",
            '<manifest ',
            1,
        )
        manifest_text = re.sub(
            r'(<manifest[^>]*>)',
            r'\1\n    <uses-permission android:name="android.permission.INTERNET" />',
            manifest_text,
            count=1,
        )
    manifest.write_text(manifest_text, encoding="utf-8")

    package_path = Path("android/app/src/main/kotlin") / Path(*APPLICATION_ID.split("."))
    package_path.mkdir(parents=True, exist_ok=True)
    activities = list(Path("android/app/src/main").rglob("MainActivity.kt"))
    if not activities:
        raise SystemExit("Generated MainActivity.kt was not found.")
    activity = activities[0]
    activity_text = activity.read_text(encoding="utf-8")
    activity_text, count = re.subn(r'(?m)^package\s+[^\n]+', f"package {APPLICATION_ID}", activity_text, count=1)
    if count != 1:
        raise SystemExit("Could not update MainActivity package declaration.")
    destination = package_path / "MainActivity.kt"
    destination.write_text(activity_text, encoding="utf-8")
    if activity.resolve() != destination.resolve():
        activity.unlink()

    print(f"Configured Android application ID: {APPLICATION_ID}")
    print(f"Configured Persian app label: {APP_LABEL}")


if __name__ == "__main__":
    main()
