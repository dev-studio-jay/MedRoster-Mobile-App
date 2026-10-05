# MedRoster — Mobile App

**Blaze Studios** · `com.blazestudios.medroster`

Flutter client for MedRoster — hospital workforce management for Ghana Health Service facilities.

Signs in with **Firebase Auth** and talks to the MedRoster API for hospitals, wards, staff, import, and schedules.

---

## Stack

- **Flutter** (Dart 3.9+)
- **Firebase Auth** + `firebase_core`
- **go_router** for navigation
- **http** + secure storage for API calls with ID tokens

---

## Getting started

> **Firebase first:** Follow [FIREBASE_SETUP.md](../FIREBASE_SETUP.md) to register Android/iOS apps, download config files, and run `flutterfire configure`.

1. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

2. Ensure Firebase is configured for your platforms (`lib/firebase_options.dart` via FlutterFire CLI, plus Android/iOS GoogleService files if needed).

3. Start the [backend](https://github.com/blaze308/medroster-backend) on port 4000.

4. Point the app at the API (defaults to Android emulator → host machine):

   ```bash
   # Android emulator (default)
   flutter run

   # Physical device / other host
   flutter run --dart-define=API_URL=http://YOUR_LAN_IP:4000

   # iOS simulator
   flutter run --dart-define=API_URL=http://localhost:4000
   ```

---

## Screens

| Route | Screen |
|-------|--------|
| `/auth/login` | Sign in |
| `/auth/register` | Register admin + hospital |
| `/` | Hospital shell (redirects to a ward) |
| `/ward/:wardId` | Ward home |
| `/import/:wardId` | Import roster |
| `/schedule/:schedId` | Roster calendar |
| `/wards` | Add / edit wards |
| `/settings` | Join code |
| `/setup` | First department + ward |

Unauthenticated users are redirected to login.

---

## Project structure

```
lib/
├── main.dart
├── firebase_options.dart
├── services/
│   ├── auth_service.dart
│   └── api_service.dart
├── state/
│   └── hospital_store.dart
├── util/
│   ├── dates.dart
│   └── org_units.dart
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── hospital_shell.dart
│   ├── ward_home_screen.dart
│   ├── import_roster_screen.dart
│   ├── schedule_screen.dart
│   ├── staff_form_screen.dart
│   ├── wards_screen.dart
│   ├── settings_screen.dart
│   └── setup_screen.dart
└── widgets/
    ├── empty_state.dart
    └── error_view.dart
```

---

## Release build (Play Store)

Solo dev workflow — no CI. From `app/`:

```powershell
flutter pub get
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.

## TODO

- [ ] **Shorebird** — OTA patches without a full store release each time ([shorebird.dev](https://shorebird.dev))

---

| Repo | Role |
|------|------|
| [medroster-backend](https://github.com/blaze308/medroster-backend) | Express + Firestore API |
| [medroster-frontend](https://github.com/blaze308/medroster-frontend) | Next.js web client |

---

*Built for Ghanaian healthcare excellence.*
