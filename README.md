# Pioji

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

## Known blocker

The API currently rejects admin credentials at `POST /auth/login`, so the app can't sign in yet. See [agent/STATUS.md](agent/STATUS.md).

## Releasing (Android)

GitHub Actions builds and signs the APK; nothing needs building locally.

1. Push your changes to `main`.
2. Tag the version and push the tag:

   ```bash
   git tag v0.1.1 && git push origin v0.1.1
   ```

3. The **Android release** workflow builds `Pioji-0.1.1.apk` and attaches it to the `v0.1.1` GitHub Release (about 10 minutes).

The version name comes from the tag; the build number goes up by one with each run. To get a test APK without a release, open **Actions → Android release → Run workflow**; the APK is kept as a run artifact for 14 days.

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
