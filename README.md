# Pioji

[![Download APK](https://img.shields.io/badge/Android-Download%20APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/besaoct/pioji-mobile/releases/latest/download/Pioji.apk)
[![Android release](https://github.com/besaoct/pioji-mobile/actions/workflows/android-release.yml/badge.svg)](https://github.com/besaoct/pioji-mobile/actions/workflows/android-release.yml)

**[Download the latest APK](https://github.com/besaoct/pioji-mobile/releases/latest/download/Pioji.apk)** · [All releases](https://github.com/besaoct/pioji-mobile/releases) (sign in to GitHub with access to this repo)

A Flutter app for iOS and Android for tea trading teams: samples, batches, offer lists, buyer allocation, the bid book, courier, contracts, sales and ex-factory reconciliation. It talks to the Tea ERP Laravel API.

- **App ID:** `com.gitcs.pioji` (iOS and Android)
- **Design:** palette "Assam green iOS", borderless cards, system font, light and dark
- **Stack:** Flutter 3.44 · Riverpod 3 · go_router 18 · Dio 5

## Getting started

```bash
flutter pub get
```

```bash
flutter run --dart-define=API_BASE_URL=https://gold-sardine-283964.hostingersite.com/api/v1
```

`API_BASE_URL` defaults to the production URL above, so plain `flutter run` works too.

Before release:

```bash
flutter analyze
```

```bash
flutter build ipa --obfuscate --split-debug-info=build/symbols
```

```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```

## Project layout

```
lib/core/       design tokens, theme, network, router, shared widgets
lib/features/   one folder per module (data + presentation)
assets/icon/    app icon and splash sources (SVG + PNG)
agent/          docs, API reference, design system, mockups, status
```

## Documentation

Start with [agent/README.md](agent/README.md). It links to:

- [API reference](agent/docs/API_DOCS.md)
- [Implementation spec](agent/docs/FLUTTER_IMPLEMENTATION.md)
- [Design system](agent/design/DESIGN_SYSTEM.md) and [screen mockups](agent/design/ui-reference/)
- [Code conventions](agent/CONVENTIONS.md)
- [Current status and blockers](agent/STATUS.md)

## API status

Sign-in and every module's list, detail, create, edit and delete work against the staging API (re-checked 7 Nov 2026), except:

| Needs fixing | Effect in the app |
|---|---|
| Sales register list returns 500 | Sales register list doesn't load (detail, create, edit and delete work) |
| Offer edit doesn't save parties or packing date | Shown read-only on the edit screen |
| Offers save only parties 1–5 | Add party is capped at 5 |
| Some errors return 500 instead of 422, with SQL in the message | Generic error message |
| No create buyer / seller API | Buyers and sellers can only be picked |

The full list, what works, and which fixes need an app update: [agent/STATUS.md → API status](agent/STATUS.md#api-status).

## Releasing (Android)

GitHub Actions builds, signs and publishes the APK; nothing needs building locally.

1. Bump `version:` in `pubspec.yaml` (e.g. `0.1.1+1` → `0.1.2+1`).
2. Commit and push to `main`.

The **Android release** workflow sees the new version, tags `v0.1.2`, builds `Pioji-0.1.2.apk` and publishes the `v0.1.2` GitHub Release (about 10–15 minutes). Pushes that don't change the version, or that change it to one already released, build nothing.

- Only the version name (`0.1.2`) matters; the build number is set by the workflow and goes up with every run.
- Pushing a `v*` tag by hand also builds and releases.
- For a test APK without a release: **Actions → Android release → Run workflow**. The APK is kept as a run artifact for 14 days.

Signing uses four repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` and `ANDROID_KEY_ALIAS`. Keep an offline backup of the keystore (`android/app/pioji-release.jks`): if it is lost, installed apps can't be updated.

## Regenerating icons

Edit `assets/icon/*.svg`, export each to a 1024 px PNG (for example `rsvg-convert -w 1024 -h 1024 icon.svg -o icon.png`), then:

```bash
dart run flutter_launcher_icons
```

```bash
dart run flutter_native_splash:create
```

## License

[MIT](LICENSE)
