# MedRoster — Mobile App

**Blaze Studios** · `com.blazestudios.medroster`

Flutter client for MedRoster — hospital workforce management for Ghana Health Service facilities.

Signs in with **Firebase Auth** and talks to the MedRoster API for hospitals, wards, staff, import, and schedules. Parity with the web client for enterprise, individual, and guest modes.

---

## Stack

- **Flutter** (Dart 3.9+)
- **Firebase Auth** + `firebase_core` + `google_sign_in`
- **go_router** for navigation
- **http** + Firebase ID tokens for API calls
- **google_fonts**, **pdf** / **excel** / **share_plus**, **shared_preferences** (guest)

---

## Getting started

> **Firebase first:** Follow [FIREBASE_SETUP.md](../FIREBASE_SETUP.md) to register Android/iOS apps, download config files, and run `flutterfire configure`.

1. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

2. Ensure Firebase is configured for your platforms (`lib/firebase_options.dart` via FlutterFire CLI, plus Android/iOS GoogleService files if needed).

3. For Google / phone auth on a physical Android device, add the app SHA-1/SHA-256 in Firebase Console. Enable Phone auth and allow Ghana under SMS region policy.

4. Start the [backend](https://github.com/blaze308/medroster-backend) on port 4000.

5. Point the app at the API:

   ```bash
   # Android emulator (default production API unless overridden)
   flutter run --dart-define=API_URL=http://10.0.2.2:4000

   # Physical device / other host
   flutter run --dart-define=API_URL=http://YOUR_LAN_IP:4000

   # iOS simulator
   flutter run --dart-define=API_URL=http://localhost:4000
   ```

---

## Screens

| Route | Screen |
|-------|--------|
| `/auth/login` | Sign in (email, Google, phone OTP) + password reset |
| `/auth/register` | Register individual or hospital |
| `/auth/join` | Join hospital via join code |
| `/guest` | Guest sandbox roster (local, capped exports) |
| `/individual` | Individual cloud schedules + upgrade |
| `/individual/:schedId` | Individual roster editor |
| `/sandbox-import/:mode` | Guest/individual import + legend setup |
| `/` | Hospital shell (redirects to ward or `/individual`) |
| `/setup` | Department template picker |
| `/ward/:wardId` | Ward home |
| `/staff/:wardId` | Add / edit staff (+ leave) |
| `/import/:wardId` | Hospital import (CSV / file / photo + legend) |
| `/schedule/:schedId` | Enterprise calendar (assign, generate, validate, export) |
| `/wards` | Add / edit departments & wards |
| `/settings` | Join code |

Unauthenticated users are redirected to login (except `/guest` and auth routes).

---

## Project structure

```
lib/
├── main.dart
├── firebase_options.dart
├── theme/app_theme.dart
├── services/
│   ├── auth_service.dart
│   └── api_service.dart
├── state/hospital_store.dart
├── util/
│   ├── dates.dart
│   ├── ghana_data.dart
│   ├── org_units.dart
│   ├── auth_errors.dart
│   ├── guest_storage.dart
│   ├── roster_setup.dart
│   ├── roster_export.dart
│   └── sandbox_roster.dart
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── join_screen.dart
│   ├── guest_screen.dart
│   ├── individual_home_screen.dart
│   ├── individual_schedule_screen.dart
│   ├── sandbox_schedule_screen.dart
│   ├── sandbox_import_screen.dart
│   ├── hospital_shell.dart
│   ├── ward_home_screen.dart
│   ├── staff_form_screen.dart
│   ├── staff_form_route.dart
│   ├── import_roster_screen.dart
│   ├── schedule_screen.dart
│   ├── wards_screen.dart
│   ├── settings_screen.dart
│   └── setup_screen.dart
└── widgets/
    ├── auth_widgets.dart
    ├── empty_state.dart
    ├── error_view.dart
    └── rules_sheet.dart
```

---

## Smoke-test checklist

- [ ] **Admin write** — register enterprise → setup templates → add ward → staff → create month roster → assign / generate / validate / export
- [ ] **Staff read-only** — join via code → open ward/schedule → cannot edit staff or assign
- [ ] **Individual** — register individual → create schedule → import → generate → export → upgrade to enterprise
- [ ] **Guest** — try as guest → import/assign → export until cap → register and confirm migrate
- [ ] **Auth** — email, Google, phone OTP, forgot password, join hospital
- [ ] **Import** — CSV template + photo/PDF roster with legend confirmation (hospital + sandbox)
- [ ] **Export share** — PDF / Excel / CSV from enterprise and sandbox schedules

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
