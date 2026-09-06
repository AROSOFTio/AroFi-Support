# AroFi Support

Official Flutter agent/support app for AroFi. It connects directly to the existing AroFi production API and shares the same support tickets, live chats, staff assignments and message history as the web console.

## Mobile platforms

- Android (APK + Play Store AAB)
- iPhone/iPad (iOS source and CI-ready project; App Store/TestFlight signing requires Apple Developer credentials)

The same Flutter codebase is structured for future desktop distribution as well.

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

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

Android package ID: `com.arosoftlabs.arofi.support`

iOS bundle ID: `com.arosoftlabs.arofi.support`

The GitHub release workflow builds a directly installable Android APK and Play Store AAB. A Play Store production upload key is intentionally supplied through repository secrets rather than committed.

For iOS, the codebase is shared with Android. A signed `.ipa` / TestFlight/App Store release requires Apple Developer signing credentials and App Store Connect setup.
