# PANTUN-CONNECT (Flutter)

Flutter port of the Kotlin/Jetpack Compose PANTUN-CONNECT app, targeting **Android + Web** from
one codebase, backed by the same Firebase project ("pantunconnect").

All `lib/` source and `pubspec.yaml` are already written. Because this sandbox doesn't have the
Flutter SDK available to run `flutter create`/`pub get`/`build`, you'll need to do a short
one-time setup on your own machine (you already have the Flutter SDK installed locally) before
this runs.

## One-time setup

Open a terminal **in this folder** (`PANTUN-CONNECT`) and run, in order:

```bash
# 1. Generate the missing platform folders (android/, web/, etc.) without touching
#    the lib/ and pubspec.yaml already written here - flutter create skips files
#    that already exist, so this is safe to run on top of this folder.
flutter create --platforms=android,web .

# 2. Fetch packages
flutter pub get

# 3. Wire real Firebase config (recommended - overwrites lib/firebase_options.dart with
#    real values for every platform, including registering a new "Web" app for you)
dart pub global activate flutterfire_cli
flutterfire configure
```

If you'd rather not use the FlutterFire CLI, you can skip step 3 and manually fill in the `web`
block in `lib/firebase_options.dart` (already has placeholder fields marked `REPLACE_WITH_...`)
from Firebase Console > Project Settings > Add app > Web.

`android/app/google-services.json` and the Google Services Gradle plugin wiring
(`android/settings.gradle.kts` + `android/app/build.gradle.kts`) are already in place, copied from
the Kotlin app's Firebase config - no extra step needed for Android to find the right Firebase
project. If you ever regenerate the `android/` folder from scratch with `flutter create`, you'll
need to redo both: drop `google-services.json` back into `android/app/`, and re-add
`id("com.google.gms.google-services") version "4.4.2" apply false` to `settings.gradle.kts`'s
`plugins {}` block plus `id("com.google.gms.google-services")` to `android/app/build.gradle.kts`'s
`plugins {}` block. Without these, `Firebase.initializeApp()` throws
`PlatformException(channel-error, Unable to establish connection on channel...)` on Android,
because the native side never gets a default `FirebaseApp` to hand the platform channel calls to.

## Google Sign-In on Web

Same prerequisite as the Android app: Google Sign-In must be enabled in Firebase Console >
Authentication > Sign-in method > Google. Once enabled, Firebase auto-registers the OAuth client
needed for `signInWithPopup` (used by `AuthRepository.signInWithGoogle` on web) - no extra
`index.html` meta tag is required for the popup-based approach used here.

## Running it

```bash
# Android (emulator or device)
flutter run -d <android-device-id>

# Web (Chrome)
flutter run -d chrome

# Production web build (outputs to build/web/, deployable to Firebase Hosting, Netlify, etc.)
flutter build web
```

To deploy the web build to Firebase Hosting (`firebase.json` in this folder already points
hosting at `build/web` and registers `firestore.rules` + `storage.rules`, so no `init` needed):

```bash
npm install -g firebase-tools   # once
firebase login                  # once
flutter build web
firebase deploy                 # deploys hosting + Firestore rules + Storage rules together
```

## Security rules & seed data

- `firestore.rules` / `storage.rules` - deploy via `firebase deploy` (above) or paste into
  Firebase Console > Firestore Database / Storage > Rules. Until these are published, every
  read/write fails with PERMISSION_DENIED (empty feed, register "error", etc.) in BOTH apps.
- `seed_data/` - 60 real pantun (10 per theme, from the "Klasifikasi Pantun 6 Tema Baharu"
  research dataset) + a curator user. Run once:
  `cd seed_data && npm install firebase-admin && node import_seed_data.js`
  (needs `serviceAccountKey.json` from Firebase Console > Project Settings > Service Accounts -
  see the comments at the top of the script).

## What carried over from the Kotlin app, and what's simplified

- **Same Firebase backend** - Firestore collections (`users`, `posts`, `chats`, `follows`,
  `reports`), Firebase Auth, Firebase Storage, and Vertex AI in Firebase (Gemini) are shared with
  the Kotlin app. Data created in one app shows up in the other.
- **Same bug fixes** carried over: resilient Google Sign-In (Firebase-first, no blocking backend
  call), Gemini fallback ordering, `getOrCreateChat`, followers/following, real chat-list names,
  profile photo upload, and the "Smart Post Creator" 6-theme AI classifier
  (`lib/models/pantun_theme.dart` + `lib/services/gemini_service.dart`).
- **Simplified vs. the Kotlin app**: no Room+Paging3 local cache for the feed (uses simple
  Firestore cursor pagination instead, `PostRepository.getFeedPage`); no backend proxy
  (`PantunApiService`) since it was never actually deployed - Vertex AI in Firebase is used
  directly.
- **Every screen is now a verified 1:1 port.** Splash, Onboarding, Forgot Password, Home (incl.
  the hand-built top bar, floating pill bottom nav, and colored Trending cards), the shared
  `PostCard` (square tinted avatar, "..." Report/Block menu, share icon), Notifications, Settings,
  Messaging (bubble colors/shape), and Post Detail were all re-read directly from the Kotlin
  source after the project folder move (`...\Project\kotlin\PANTUN-CONNECT`) and rebuilt to match
  exactly - colors, copy text, spacing, and layout structure all come from the real composables,
  not from the Business Case's screen descriptions.
- Two intentional deviations from the Kotlin source (both actual bug fixes, not stylistic
  choices): Messaging's app bar now shows the real other participant's name/avatar (Kotlin's title
  is a static "Chat" because it never resolves who the chat is with), and each message bubble's
  side is based on the real sender (Kotlin hardcodes `isCurrentUser = true` for every bubble, so it
  never actually distinguishes the two people in a conversation).

## Known gaps / things to double check

- `lib/firebase_options.dart`'s `web` block has placeholder values until you run
  `flutterfire configure` (see setup step 3) or fill them in manually.
- No `ios`/`macos`/`windows`/`linux` platform folders are requested by the `flutter create`
  command above - add them to `--platforms=` if you want those too.
- I couldn't run `flutter analyze` / `flutter pub get` / `flutter build web` here (no Flutter SDK
  in this sandbox), so please run those once after setup and fix anything that surfaces -
  I've double-checked brace/paren balance and that every relative import resolves, but that's not
  a substitute for the real Dart analyzer.
