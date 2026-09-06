# AroFi Support

Official Flutter agent/support app for AroFi. It connects directly to the existing AroFi production API and shares the same support tickets, live chats, staff assignments and message history as the web console.

## Platforms

- Android — universal APK, split APKs and Google Play AAB
- iPhone/iPad — shared Flutter app; App Store/TestFlight signing requires Apple Developer credentials
- Windows, macOS, Linux and Web/PWA — supported by the same Flutter source and platform bootstrap

## Features

- Existing AroFi staff login + email OTP
- Shared realtime support inbox
- Open / Mine / Unassigned / All / Resolved filters
- Instant foreground updates using authenticated Server-Sent Events
- Claim, transfer/unassign and status workflow
- Text, clickable links and internal notes
- Images/files up to 25 MB
- Voice recording and audio playback
- Light / Dark / Auto theme
- Existing `support.read` and `support.write` permissions enforced by the AroFi API

## Production API

The app intentionally uses `https://arofi.net/api` so no separate support database is created.

## Application identifiers

Android package ID: `com.arofi.support`

iOS bundle ID: `com.arofi.support`

These identifiers were finalized before the first public release, so future Play Store/App Store updates must keep them unchanged.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

Version 1.0.0 release artifacts include a directly installable universal Android APK, architecture-specific APKs and a Play Store AAB. Production Android signing uses the private AroFi Support upload key and must never be committed to GitHub.

For iOS, a signed `.ipa` / TestFlight / App Store release requires Apple Developer signing credentials and App Store Connect setup.
