# Release builds

Share or publish release builds, never debug ones. Debug builds are slower, signed with a shared
debug key and not accepted by Google Play.

## 1. One-time: create the release keystore

```sh
tool/make_release_keystore.sh            # default: ~/keys/fitapp-release.jks, alias fitapp
```

The script prompts for a password, creates the keystore outside the repo and writes
`android/key.properties` (git-ignored, mode 600). Never commit either.

**Back up the keystore and its password** (password manager plus an offline copy). If you lose
them you can no longer update the app on devices where it is installed.

## 2. Register the SHA-1 in Google Cloud

Google sign-in checks the signing key. The script prints the release SHA-1; add it as an extra
**Android** OAuth client (package `com.fitapp.app`) in Google Cloud Console > APIs & Services >
Credentials. See [sync-setup.md](sync-setup.md).

## 3. Build

```sh
flutter build apk --release --dart-define-from-file=env/dev.json       # sideloading
flutter build appbundle --release --dart-define-from-file=env/dev.json # Google Play
```

Outputs: `build/app/outputs/flutter-apk/app-release.apk` and
`build/app/outputs/bundle/release/app-release.aab`.

Without `android/key.properties` a release build fails on purpose. For local testing only you can
set `FITAPP_ALLOW_DEBUG_SIGNING=1` to sign with the debug key; never distribute that APK.

## What is public in the APK (by design)

The Supabase URL, the publishable (anon) key, the Google web client ID and the map key can all be
extracted from the APK. That is fine: the server protects data with Row Level Security. Never ship
the Supabase secret / `service_role` key, or any OAuth client secret.

## Pre-publish checklist

- [ ] Supabase: disable email sign-up if unused (Auth > Providers/Sign In).
- [ ] MapTiler: restrict the key (allowed origins/usage limits) in its dashboard.
- [ ] Google OAuth consent screen: move from Testing to In production.
- [ ] Privacy policy published and linked.
- [ ] Play Console data-safety form completed.
- [ ] Web link for account deletion provided (Play requirement).
- [ ] Release SHA-1 registered as Android OAuth client.
- [ ] `FITAPP_ALLOW_DEBUG_SIGNING` not used for the shipped build.
