# first_test

Flutter app (iOS-first) with a C# backend, developed on Windows.

## Dev workflow

### 1. Daily loop (Windows, fast, hot reload)
Do ~90% of UI/logic work locally — no Mac needed:

```powershell
flutter run -d chrome
```

In debug mode on web, the app runs inside a simulated **iPhone 17** (frame,
notch, safe areas, iOS scrolling/transitions) via
[`device_preview`](https://pub.dev/packages/device_preview), set up in
[lib/dev_preview.dart](lib/dev_preview.dart). To switch device, rotate, try dark
mode or large text: press `v` in the `flutter run` terminal to open DevTools ->
**device_preview** tab. Release builds (TestFlight) are unaffected.

Run the C# backend locally at the same time (`dotnet watch run`).

## Reusing this setup in another project

```powershell
.\tool\setup_ios_workflow.ps1 -ProjectPath C:\path\to\real_app -BundleId com.yusufali.realapp
```
This copies `codemagic.yaml`, `lib/dev_preview.dart`, adds `device_preview`,
sets the iOS bundle ID, the Info.plist export-compliance key, and `.gitignore`
entries. Then follow the printed steps (2 lines in `main.dart`, App Store
Connect app record, Codemagic env group). The Codemagic API key integration
and `CERTIFICATE_PRIVATE_KEY` can be reused across all your apps.

### 2. Test on the iPhone (from anywhere) — Codemagic -> TestFlight
```powershell
git push
git tag tf-1; git push origin tf-1   # bump the number each time
```
Codemagic builds on a cloud Mac and uploads to TestFlight (~10–20 min incl.
Apple processing). Open the **TestFlight** app on the iPhone and tap Update.
You can also start the `ios-testflight` workflow manually in the Codemagic UI.

Free tier = 500 Mac minutes/month (~30–40 builds), so batch changes.

### 3. Deep debugging (at home) — Mac mini
When you need hot reload / breakpoints on the real iPhone, plug it into the
Mac mini and `flutter run`. From outside the house, you can SSH into the Mac mini
over Tailscale and build there instead of using Codemagic.

## One-time setup

1. **Apple Developer Program** membership is required ($99/yr) for TestFlight.
2. **App Store Connect -> Apps -> +** : create an app with bundle ID
   `com.yusufali.firstTest` (register the ID first under
   developer.apple.com -> Identifiers if it isn't listed).
3. **Codemagic -> Team integrations -> Developer Portal**: the App Store Connect
   API key must be named `code_magic` (matches `codemagic.yaml`).
4. **Signing private key**: generate one on Windows (Git Bash):
   ```bash
   ssh-keygen -t rsa -b 2048 -m PEM -f ios_dist_key -q -N ""
   ```
   In Codemagic -> app -> Environment variables, add `CERTIFICATE_PRIVATE_KEY`
   = contents of `ios_dist_key` to a group named `ios_signing` (mark it
   secure). **Don't commit this file.** Codemagic uses it to create/reuse your
   Apple distribution certificate.
5. **TestFlight -> Internal Testing**: add yourself as a tester, then install
   the TestFlight app on the iPhone.

## Talking to the C# backend from the phone
A TestFlight build on your phone cannot reach `localhost` on your laptop. Options:

- **Dev tunnel** (easiest while developing): `devtunnel host -p 5000 --allow-anonymous`
  gives an `https://...devtunnels.ms` URL that forwards to your laptop.
- **Host it** (Azure App Service, Fly.io, Railway, etc.) once it's stable.

Set the URL in `API_BASE_URL` in `codemagic.yaml`. Read it in Dart with:
```dart
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');
```
Use HTTPS: iOS blocks plain `http://` by default (App Transport Security).
