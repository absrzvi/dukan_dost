# Dukaan Dost — APK Distribution Guide

> This document is the single source of truth for building, signing, and distributing the Dukaan Dost Android APK to testers.

---

## 1. Backend URL Configuration

The APK's backend URL is baked in at **compile time** via `--dart-define`.

The canonical constant lives in:
```
mobile/lib/config/env.dart
```

**Default (emulator / local dev):** `http://10.0.2.2:8000`
- `10.0.2.2` is the Android emulator's alias for `localhost` on the host machine.
- Used automatically when no `--dart-define` is passed.
- Works with `flutter run` against a locally-running Django server.

**Physical device on same Wi-Fi:**
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
```

**Deployed backend (for tester APKs):**
```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.railway.app
```

---

## 2. Building the Release APK

### Prerequisites
- Flutter 3.x installed (`C:\flutter\bin\flutter.bat`)
- Android SDK installed via Android Studio
- `mobile/` directory is the working directory

### Build command

```powershell
cd mobile

# With a deployed backend URL:
C:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://your-backend.railway.app

# With a temporary ngrok URL:
C:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://abc123.ngrok.io

# Local emulator (default — no dart-define needed):
C:\flutter\bin\flutter.bat build apk --release
```

### Output location
```
mobile\build\app\outputs\flutter-apk\app-release.apk
```

Build time: ~3–5 minutes (first build downloads dependencies).

---

## 3. Signing

> ⚠️ **Current status: debug keystore only.**
> The release APK is currently signed with Flutter's default debug keystore (`~/.android/debug.keystore`). This is sufficient for sideloading to testers but **must not be published to the Play Store**.

Production keystore setup (future):
- Generate a keystore: `keytool -genkey -v -keystore release.jks -alias dukaan_dost -keyalg RSA -keysize 2048 -validity 10000`
- Add signing config to `mobile/android/app/build.gradle`
- Store `release.jks` securely (never commit to git)

---

## 4. Verifying the injected URL

To confirm the URL was baked into the APK correctly, run this after building:

```powershell
# On Windows (requires strings utility or apktool)
# Quickest check — search the APK binary for the URL:
Select-String -Path "build\app\outputs\flutter-apk\app-release.apk" -Pattern "your-backend" -Encoding Byte
```

Or use `apkanalyzer` from the Android SDK:
```powershell
$SDK = "$env:LOCALAPPDATA\Android\Sdk"
& "$SDK\cmdline-tools\latest\bin\apkanalyzer.bat" dex packages build\app\outputs\flutter-apk\app-release.apk | findstr "apiBaseUrl"
```

---

## 5. Release Checklist

Before tagging a GitHub Release:

- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes with zero failures
- [ ] APK built with the correct `API_BASE_URL` for this release
- [ ] Backend is deployed and responding at that URL
- [ ] Version number bumped in `mobile/pubspec.yaml` (`version: X.Y.Z+build`)
- [ ] APK tested on at least one physical device

### Tagging a release

```bash
git tag -a v0.1.0 -m "Release v0.1.0 — first tester build"
git push origin v0.1.0
```

Then on GitHub:
1. Go to **Releases → Draft a new release**
2. Select the tag `v0.1.0`
3. Attach `app-release.apk` as a release asset
4. Include the SHA-256 hash in the release body:
   ```powershell
   Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
   ```
5. Publish the release

Testers download from: `https://github.com/absrzvi/dukan_dost/releases/latest`

---

## 6. Sharing with testers (quick options)

| Method | Best for | Notes |
|---|---|---|
| **GitHub Releases** | Stable tester builds | Permanent URL, version history |
| **WhatsApp** | Ad-hoc 1-on-1 sharing | Works for APKs up to ~100 MB |
| **Google Drive** | Small groups | Share "anyone with link" |
| **ngrok** | Developer-to-developer testing | Temporary; see `docs/ngrok-guide.md` |

---

## 7. No hardcoded URLs policy

The following must **never** appear hardcoded outside `env.dart` or test fixtures:
- `10.0.2.2`
- `localhost`
- `127.0.0.1`
- Any production domain

All HTTP clients in the app read from `apiBaseUrl` imported from `mobile/lib/config/env.dart`.
