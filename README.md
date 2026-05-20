# Vynl — AI Music Player

**BS Computer Science — 6th Semester**  
**Mobile Applications Development**  
**Project: Vynl (`music_player`)**

Vynl is an Android-first Flutter music player that plays **local audio**, enriches your library with **Last.fm** metadata, adds **social listening** and **blend compatibility** via **Firebase**, and understands voice commands through **on-device speech recognition** plus **Google Gemini** intent parsing.

---

## Overview

| Layer | Technology |
|--------|------------|
| UI | Flutter (Material 3), custom vinyl animations |
| State | `provider` (`ChangeNotifier` + proxy providers) |
| Local audio | `on_audio_query`, `just_audio`, `just_audio_background` |
| Auth | Firebase Auth (Google Sign-In, email/password) |
| Cloud data | Firebase Realtime Database |
| Analytics | Firebase Analytics |
| AI voice | `speech_to_text` + **Gemini 2.0 Flash** (optional) + local keyword fallback |
| Metadata | Last.fm API (`track.getInfo`) |

**Not used:** YouTube Data API, cloud music streaming, or a traditional SQL database. Playback is always from files on the device.

---

## Features

### Authentication
- **Auth gate:** The app home is `AuthGate` — unauthenticated users only see `AuthScreen`.
- **Protected routes:** Named routes (`/now-playing`, `/playlists`) are wrapped in `AuthRequired`.
- **Session restore:** Waits for Firebase `authStateChanges` before showing login or main UI (avoids login flash).
- **Sign-in methods:** Google Sign-In and email/password (register + sign in).
- **Validation:** Client-side email format and minimum password length before Firebase calls.
- **Sign-out:** Clears analytics user id and removes the user’s `nowPlaying` RTDB entry.

### Library & playback
- Scans device storage (`on_audio_query`) with storage permission handling
- Search and sort (Title A–Z, Artist A–Z, Recently added)
- Play / pause / seek / shuffle / repeat (off, all, one)
- Background playback with notification controls
- Liked songs and recently played (SharedPreferences)
- **Enrichment:** Album art URLs and genres from Last.fm, cached in Firebase `songMeta` + local prefs (capped batch per scan for performance)

### Now playing
- Spinning vinyl at 33⅓ RPM (`CustomPainter`)
- Tone-arm needle animation, buffering pulse, error shake
- Gestures: tap play/pause, double-tap like, swipe skip, long-press details

### Social
- Live **Now Playing** feed (`nowPlaying/{uid}`) for other signed-in users
- **Blend:** Compares listening histories (genres, artists, time-of-day) — requires both users to have played songs while signed in
- Listening history recorded on each play (`users/{uid}/listeningHistory`)

### Group listening rooms
- Create/join rooms with a 6-character code (in-memory simulation)
- Queue, voting, emoji reactions, chat UI
- *Not networked* — participants are simulated locally (ready for a future WebSocket/Firebase backend)

### AI voice search
- Android speech-to-text for transcripts
- **Gemini** parses intent when `GEMINI_API_KEY` is set and confidence &gt; 0.6
- **Local keyword maps** as offline fallback (moods, activities, controls)
- Suggestion chips and command history

### Profile
- Avatar colours, username, stats (liked count, library size, listening time)
- Dark mode, microphone permission, sign out

### Mini-player
- Glass-style bar above bottom navigation on all main tabs
- Collapsed and expanded states with seek bar and controls

---

## Architecture

```
lib/
├── main.dart                 Firebase init, providers, MaterialApp, analytics observer
├── firebase_options.dart     Generated Firebase config
│
├── core/
│   ├── auth/auth_guard.dart  AuthRequired route wrapper
│   ├── constants/            Colors, routes, env keys, prefs keys
│   ├── theme/app_theme.dart  Light / dark Material 3
│   └── utils/                Permissions, helpers
│
├── features/
│   ├── auth/                 AuthGate, AuthScreen, AuthProvider
│   ├── library/              Scan, enrichment, playlists, liked/recent
│   ├── now_playing/          Vinyl UI, full player screen
│   ├── social/               Feed, blend, SocialProvider
│   ├── rooms/                Simulated group rooms
│   ├── voice/                STT + Gemini + local parser
│   └── profile/              Settings and stats
│
├── services/
│   ├── analytics_service.dart
│   ├── gemini_service.dart
│   └── music_enrichment_service.dart
│
└── shared/
    ├── providers/            AudioProvider, ThemeProvider
    └── widgets/              MainScaffold, mini player, empty states
```

### Provider dependency graph

```
ThemeProvider
AuthProvider
LibraryProvider
    └── SocialProvider (Proxy: Auth)
            └── AudioProvider (Proxy2: Library + Social)
                    ├── VoiceProvider (Proxy2: Audio + Library)
                    └── RoomProvider (Proxy: Audio)
PlaylistProvider (Proxy: Library)
ProfileProvider
```

`ChangeNotifierProxyProvider` injects upstream providers so playback can record social history and voice can control audio.

### Data stores

| Store | Contents |
|--------|----------|
| **Device files** | Actual audio (MP3, etc.) |
| **SharedPreferences** | Liked IDs, recent plays, theme, profile, local enrichment cache |
| **Firebase RTDB** | `users/{uid}`, `listeningHistory`, `nowPlaying`, shared `songMeta` |
| **Last.fm** | Track info (art, tags) — not stored on Last.fm servers by this app beyond API calls |
| **Gemini API** | Stateless intent parsing per voice request |

---

## Security model

### Client (Flutter)
- Main UI only after `AuthProvider.isAuthenticated`
- `SocialProvider` / Firebase writes check auth before RTDB access
- `LibraryProvider` uses Firebase `songMeta` only when `FirebaseAuth.instance.currentUser != null`
- Named routes require `AuthRequired`

### Server (Firebase Realtime Database)
Deploy `database.rules.json` from the project root. Summary:

| Path | Read | Write |
|------|------|-------|
| Root | Deny | Deny |
| `nowPlaying` (list all) | Any signed-in user | — |
| `nowPlaying/{uid}` | Any signed-in user | Only `auth.uid == $uid` |
| `users/{uid}` | Any signed-in user | Only owner |
| `users/{uid}/listeningHistory/*` | Any signed-in user | Only owner |
| `songMeta/*` | Any signed-in user | Any signed-in user (shared enrichment cache) |
| `rooms` (and children) | Any signed-in user | Any signed-in user |
| `feed` | Any signed-in user | Any signed-in user (reserved; app uses `nowPlaying`) |

**Important:** Until these rules are published in the Firebase Console, RTDB features will log `permission-denied`. Room join/create reads `rooms/{code}` before you are a participant — stricter per-room rules in older commits caused rooms to kick users out; the flat `rooms` rules above match what the app expects.

---

## Analytics events

Implemented via `AnalyticsService` and `FirebaseAnalyticsObserver` (screen views):

| Event | When |
|--------|------|
| `login` / `sign_up` | Successful auth |
| `song_played` | Track starts |
| `voice_command` | Voice intent executed (parser: `gemini` or `local`) |
| `blend_calculated` | Blend screen completes |
| `library_scan` | Library scan finishes |
| `library_enrichment` | Background enrichment completes |

User id is set on auth state change and cleared on sign-out.

---

## Environment variables

Create a `.env` file in the project root (bundled as a Flutter asset — **do not commit secrets**):

```env
GEMINI_API_KEY=your_google_ai_studio_key
LASTFM_API_KEY=your_lastfm_api_key
```

| Key | Used for |
|-----|----------|
| `GEMINI_API_KEY` | Voice intent parsing (`gemini-2.0-flash`) |
| `LASTFM_API_KEY` | Album art + genre enrichment |

If Gemini key is missing, voice still works via local keywords. If Last.fm key is missing, enrichment uses genre heuristics only.

---

## Getting started

### Prerequisites
- Flutter SDK ≥ 3.1.0
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API 21+)
- Firebase project with Auth, Realtime Database, and Analytics enabled
- `google-services.json` in `android/app/` (already present for team project `vynl-b454c`)

### Setup

```bash
# Install dependencies
flutter pub get

# Add API keys (see Environment variables above)
# copy .env.example .env   # if example file exists; otherwise create .env manually

# Deploy RTDB rules (Firebase CLI) or paste database.rules.json in Console
firebase deploy --only database

# Run
flutter run
```

On first launch:
1. Sign in (Google or email)
2. Grant **audio/storage** permission for library scan
3. Grant **microphone** permission for voice search

---

## Android permissions

| Permission | Purpose |
|------------|---------|
| `READ_MEDIA_AUDIO` (API 33+) | Read local audio |
| `READ_EXTERNAL_STORAGE` (API ≤ 32) | Read local audio |
| `RECORD_AUDIO` | Voice search |
| `FOREGROUND_SERVICE` / `MEDIA_PLAYBACK` | Background audio |
| `INTERNET` | Firebase, Last.fm, Gemini |

---

## Design system

Palette tokens in `AppColors`: `darkBerry`, `roseQuartz`, `blush`, `sage`, `stone`.  
Typography: `GoogleFonts.poppins()`.  
Spacing: 8px grid (`AppConstants`).

---

## Known limitations

- **Rooms** are simulated locally, not real-time multiplayer.
- **Enrichment** fetches up to 40 uncached tracks per library scan (remaining tracks on next scan).
- **Blend** needs listening history from both accounts (play songs while signed in).
- **YouTube API** is not integrated.
- **iOS** may need extra Firebase/Google Sign-In setup beyond the Android-focused config.

---

## Firebase setup (required)

Step-by-step guide: **[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)**

Covers Authentication providers, RTDB rules deploy, Analytics debug, and Cloud Functions.

## Real-time rooms

Rooms sync via `rooms/{code}` in Realtime Database (participants, queue, chat, votes). Join with a 6-character code on another signed-in device.

## Cloud Functions

See **[functions/README.md](functions/README.md)** — `trimListeningHistory` caps history at 200 entries per user.

## Suggested future enhancements

- Stricter `songMeta` write validation
- iOS Firebase / Google Sign-In parity
- Room host handoff and private rooms
- CI workflow and integration tests

---

## License / academic use

Course project for Mobile Applications Development. Firebase and API keys are team-specific; do not commit `.env` to public repositories.
