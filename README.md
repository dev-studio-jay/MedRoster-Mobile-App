# MedRoster — Mobile App

**Blaze Studios** · `com.blazestudios.medroster`

Flutter client for MedRoster — hospital workforce management for Ghana Health Service facilities.

Signs in with **Firebase Auth** and talks to the [MedRoster API](https://github.com/blaze308/medroster-backend) for hospitals, departments, staff, and schedules.

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
| `/` | Dashboard |
| `/departments` | Departments |
| `/staff` | Staff directory |
| `/schedules` | Schedules list |

Unauthenticated users are redirected to login.

---

## Project structure

```
lib/
├── main.dart
├── firebase_options.dart
├── services/
│   ├── auth_service.dart     # Firebase Auth
│   └── api_service.dart      # Bearer-token HTTP client
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── dashboard_screen.dart
│   ├── departments_screen.dart
│   ├── staff_screen.dart
│   └── schedules_screen.dart
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
