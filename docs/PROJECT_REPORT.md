# Vynl — Complete Project Report

**Course:** Mobile Applications Development (BS Computer Science, 6th Semester)  
**Project name:** Vynl (`music_player`)  
**Platform:** Android-first Flutter app  
**Firebase project:** `vynl-b454c`  
**Package / application ID:** `com.example.music_player`

---

## 1. Executive summary

**Vynl** is an AI-assisted music player for Android that:

1. Plays **local audio files** from the device (not cloud streaming).
2. Enriches tracks with **album art and genres** via the **Last.fm API**, cached locally and in Firebase.
3. Uses **Firebase Authentication** and **Realtime Database** for user profiles, social “Listening Now,” blend compatibility, shared metadata, and real-time group rooms.
4. Accepts **voice commands** using on-device **speech-to-text**, optional **Google Gemini** intent parsing, and an offline keyword fallback.
5. Tracks usage with **Firebase Analytics** and optional **Cloud Functions** to trim listening history.

The app is built with **Flutter**, **Provider** state management, and a feature-based folder structure under `lib/`.

---

## 2. What the app does (user-facing)

| Area | What the user experiences |
|------|---------------------------|
| **Sign in** | Google account or email/password; session restored on reopen |
| **Library** | All local songs scanned; search and sort; album art and genre appear as metadata loads |
| **Playback** | Play/pause, seek, shuffle, repeat; mini-player on every tab; full Now Playing with vinyl animation |
| **Social** | See what other signed-in users are playing live; compare taste via “Blend” using Firebase UID |
| **Rooms** | Create or join a 6-character room code; shared queue, votes, chat, reactions (Firebase-synced) |
| **Voice** | Tap mic, speak (“play jazz”, “pause”, “what’s playing”); Gemini or local parser runs the command |
| **Profile** | Avatar, username, stats, dark mode, copy user ID, sign out |

**Important:** Music files never leave the phone for playback. Only metadata, social state, and room data go to Firebase/APIs.

---

## 3. Technology stack

| Layer | Technology | Role |
|-------|------------|------|
| UI | Flutter (Material 3), `google_fonts` (Poppins) | Screens, animations, theming |
| State | `provider` (`ChangeNotifier`, proxy providers) | Auth → Social → Audio → Voice/Rooms |
| Local audio scan | `on_audio_query` | Read device music library |
| Playback | `just_audio`, `just_audio_background`, `audio_session` | Player + notification controls |
| Local persistence | `shared_preferences` | Likes, recents, theme, enrichment cache, playlists |
| Auth | `firebase_auth`, `google_sign_in` | Google + email/password |
| Cloud DB | `firebase_database` | RTDB paths (see §8) |
| Analytics | `firebase_analytics` | Events + screen observer |
| HTTP | `dio`, `http` | Last.fm, Gemini |
| Voice STT | `speech_to_text` | On-device transcription |
| Images | `cached_network_image` | Remote album art |
| Secrets | `flutter_dotenv` + `.env` asset | API keys (not committed) |

**Not used:** YouTube Data API, Spotify, cloud music hosting, SQL database.

---

## 4. Authentication (complete)

### 4.1 Sign-in methods

| Method | Implementation | Notes |
|--------|----------------|-------|
| **Google Sign-In** | `GoogleSignIn` → `GoogleAuthProvider.credential` → `FirebaseAuth.signInWithCredential` | Requires SHA-1 in Firebase Console + `google-services.json` |
| **Email / password — sign in** | `signInWithEmailAndPassword` | Email regex + password ≥ 6 chars validated client-side |
| **Email / password — register** | `createUserWithEmailAndPassword` + `updateDisplayName` | Sends verification email after signup |
| **Password reset** | `sendPasswordResetEmail` | From Auth screen “Forgot password” |
| **Email verification** | `sendEmailVerification` | After registration |
| **Sign out** | `GoogleSignIn.signOut()` + `FirebaseAuth.signOut()` | Clears Analytics user id; Social removes `nowPlaying/{uid}` |

### 4.2 Auth flow in the app

```
App launch
  → main(): load .env, Firebase.initializeApp, JustAudioBackground.init
  → MaterialApp home: AuthGate
       → waits AuthProvider.isReady (first authStateChanges)
       → if not authenticated: AuthScreen
       → if authenticated: MainScaffold (5 tabs)
```

- **AuthGate** (`lib/features/auth/auth_gate.dart`): Prevents login “flash” while Firebase restores session.
- **AuthRequired** (`lib/core/auth/auth_guard.dart`): Wraps named routes `/now-playing`, `/playlists`.
- **First-time profile:** On any successful sign-in, `_ensureUserProfile` creates `users/{uid}` in RTDB if missing (display name, email, photo, stats placeholders).

### 4.3 Google Cloud / Firebase Console (auth-related)

| Console | What to configure |
|---------|-------------------|
| **Firebase → Authentication → Sign-in method** | Enable **Email/Password** and **Google** |
| **Firebase → Project settings → Your apps → Android** | Package `com.example.music_player`; add **SHA-1** from `gradlew signingReport` |
| **Google Cloud Console** (linked to Firebase) | OAuth client for Android auto-created when Google provider enabled |
| **Authentication → Settings → Authorized domains** | For web/email links if needed |

---

## 5. External APIs and keys

### 5.1 Environment file (required for full features)

Create **`/.env`** (bundled as Flutter asset; copy from `.env.example`):

```env
GEMINI_API_KEY=your_google_ai_studio_key
LASTFM_API_KEY=your_lastfm_api_key
```

| Key | Service | Endpoint / usage |
|-----|---------|------------------|
| `LASTFM_API_KEY` | [Last.fm API](https://www.last.fm/api) | `https://ws.audioscrobbler.com/2.0/` — `track.getInfo`, `tag.gettoptracks` |
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/) | `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent` |

If **Last.fm** key is missing: genres fall back to heuristics from artist/title; no remote album art.  
If **Gemini** key is missing: voice still works via **local keyword maps** in `VoiceProvider`.

### 5.2 Firebase services (no separate API key in app)

Configured via `google-services.json` + `firebase_options.dart`:

| Service | Purpose |
|---------|---------|
| Firebase Auth | Users |
| Realtime Database | Social, rooms, songMeta, profiles |
| Firebase Analytics | Events + automatic screen tracking |
| Cloud Functions (optional) | `trimListeningHistory` |

**RTDB URL:** `https://vynl-b454c-default-rtdb.asia-southeast1.firebasedatabase.app`

---

## 6. Screens and navigation

### 6.1 Main shell (bottom navigation)

`MainScaffold` uses `IndexedStack` — all tabs stay alive in memory.

| Tab # | Label | Widget | Purpose |
|-------|-------|--------|---------|
| 0 | Library | `LibraryScreen` | Song list, search, sort, playlists entry, liked/recent |
| 1 | Social | `SocialScreen` | “Listening Now” feed |
| 2 | Rooms | `RoomsScreen` | Create/join room, history |
| 3 | AI Voice | `VoiceScreen` | Microphone, transcript, suggestions |
| 4 | Profile | `ProfileScreen` | Settings, stats, sign out |

**Mini-player:** `MiniPlayerStub` above bottom nav on all tabs; tap opens Now Playing.

### 6.2 Secondary / pushed screens

| Screen | How opened | Purpose |
|--------|------------|---------|
| `AuthScreen` | Auth gate when logged out | Login, register, Google, forgot password |
| `NowPlayingScreen` | Route `/now-playing`, mini-player | Vinyl UI, seek, like, skip gestures |
| `BlendScreen` | Social app bar → people icon | Paste friend UID, compatibility score |
| `ActiveRoomScreen` | Rooms after create/join | Queue, chat, vote, participants |
| `PlaylistScreen` | Route `/playlists` | Manage playlists |
| `PlaylistDetailScreen` | From library | Songs in one playlist |
| `LikedSongsScreen` | Library menu | Liked tracks only |

### 6.3 Assets and images

Declared in `pubspec.yaml`:

| Asset path | Use |
|------------|-----|
| `.env` | API keys |
| `assets/icons/app_icon.png` | Launcher icon |
| `assets/icons/app_icon_foreground.png` | Adaptive icon foreground |
| `assets/images/` | Static UI images (if referenced in widgets) |

**Album art in UI:** Mostly **network URLs** from Last.fm (`cached_network_image`), not bundled per song. Device embedded art may be used via `MediaArtHelper` for notifications.

**Design tokens:** `AppColors` (darkBerry, roseQuartz, blush, sage, stone), `AppTextStyles` (Poppins), `AppConstants` (8px spacing grid).

---

## 7. Architecture and provider graph

```
ThemeProvider
AuthProvider
LibraryProvider  ──scan on start──► on_audio_query
    │
    └── SocialProvider (Proxy: Auth)
            └── AudioProvider (Proxy2: Library + Social)
                    ├── VoiceProvider (Proxy2: Audio + Library)
                    └── RoomProvider (Proxy: Audio + Auth)
PlaylistProvider (Proxy: Library)
ProfileProvider
```

**Why proxies:** Playback must write social/history only when authenticated; voice needs current library genres; rooms need auth uid and audio control.

---

## 8. Firebase Realtime Database structure

Deploy rules from **`database.rules.json`** (see `docs/FIREBASE_SETUP.md`).

| Path | Written by | Read by | Content |
|------|------------|---------|---------|
| `users/{uid}` | Owner on first login | Any authed user | Profile, stats |
| `users/{uid}/listeningHistory/{id}` | Owner on each play | Any authed user | title, artist, genre, hour, timestamp |
| `nowPlaying/{uid}` | Owner while playing | Any authed user | Live track card for social feed |
| `songMeta/{songKey}` | Any authed user after enrichment | Any authed user | Shared Last.fm cache (genre, albumArtUrl) |
| `rooms/{code}/...` | Room participants | Any authed user | participants, queue, messages, votes, status |

**Security summary:** Default deny; authenticated read for social data; writes scoped to own uid for profile/history/nowPlaying; rooms and songMeta writable by any signed-in user (team project choice).

**Cloud Function:** `trimListeningHistory` — on new history entry, deletes oldest entries beyond 200 per user (requires Blaze plan).

---

## 9. Core features — technical detail

### 9.1 Library scan and enrichment

**Scan (`LibraryProvider.scanLibrary`):**

1. Request storage/audio permission (`PermissionHelper`).
2. `OnAudioQuery.querySongs` — external URI, title sort.
3. Filter: duration > 10s, valid URI.
4. Map to `SongItem` model.

**Enrichment (album art + genre):**

1. On scan end, `_hydrateFromCache()` loads Firebase `songMeta` + local `song_enrichment_v2` prefs.
2. **Visible-row enrichment:** When a list tile builds, `enrichSongIfNeeded(song)` calls Last.fm `track.getInfo` (max 4 concurrent).
3. Results saved to RTDB `songMeta/{hash}` and SharedPreferences.
4. If Last.fm fails, `_guessGenre()` uses keyword heuristics on artist/title.

**User action to load art:** Scroll the library — art loads for visible rows, not all songs at once.

### 9.2 Playback (`AudioProvider`)

- Engine: `just_audio` `AudioPlayer`.
- Background: `JustAudioBackground` + `MediaItem` tags.
- Queue, shuffle, repeat (off / one / all).
- On track start: `broadcastNowPlaying`, `recordListeningHistory`, `AnalyticsService.logSongPlayed`.
- Listening time accumulated in session, persisted to `PrefsKeys.listeningTime`.

### 9.3 Social (`SocialProvider`)

- **Listening Now:** Real-time listener on `nowPlaying`; excludes self; shows entries &lt; 10 minutes old.
- **Blend:** Reads both users’ `listeningHistory` (last 100), computes genre overlap, shared artists, time-of-day similarity → compatibility %.

### 9.4 Rooms (`RoomProvider`)

- **Real-time** via RTDB under `rooms/{code}`.
- Create: allocate unique 6-char code, set host, add self as participant, `onDisconnect` cleanup.
- Join: validate code exists, add participant.
- Listeners: room meta, participants, queue, messages, votes.
- Host controls: skip, settings; shared queue playback sync via `_maybeSyncPlayback`.

### 9.5 Voice (`VoiceProvider`)

1. `speech_to_text` captures audio → transcript.
2. Local keyword parser (`_parseIntent`) — moods, genres, play/pause/next.
3. `GeminiService.parseVoiceCommand` if key set and confidence &gt; 0.6.
4. `_executeCommand` — play genre/mood/random, controls, like, what’s playing.

### 9.6 Profile (`ProfileProvider` + screen)

- Local prefs: username, avatar index, theme.
- Stats from `LibraryProvider` + `AudioProvider` + room prefs.
- Copy Firebase UID for Blend.

---

## 10. Important classes and functions (reference)

| File | Class / function | Responsibility |
|------|------------------|----------------|
| `main.dart` | `main`, `VynlApp` | Init Firebase, dotenv, audio background, register providers |
| `auth_provider.dart` | `signInWithGoogle`, `signInWithEmail`, `registerWithEmail`, `_ensureUserProfile` | All auth + RTDB user node |
| `auth_gate.dart` | `AuthGate` | Route logged-in vs login UI |
| `library_provider.dart` | `scanLibrary`, `enrichSongIfNeeded`, `_loadEnrichmentFromFirebase` | Library + metadata |
| `music_enrichment_service.dart` | `getTrackInfo`, `searchByGenre` | Last.fm HTTP |
| `audio_provider.dart` | `playSong`, `_loadAndPlay`, `playPause`, `skipToNext` | Playback engine |
| `social_provider.dart` | `broadcastNowPlaying`, `_startListeningFeed`, `calculateBlend` | Social + blend |
| `room_provider.dart` | `createRoom`, `joinRoom`, `leaveRoom`, `_attachRoomListeners` | Multi-user rooms |
| `voice_provider.dart` | `startListening`, `_parseAndExecute`, `_executeCommand` | Voice pipeline |
| `gemini_service.dart` | `parseVoiceCommand` | Gemini JSON intent |
| `analytics_service.dart` | `logSongPlayed`, `logVoiceCommand`, etc. | Firebase Analytics |
| `permission_helper.dart` | `requestStorage`, `requestMicrophone` | Android permissions |
| `auth_guard.dart` | `AuthRequired` | Protect routes |

---

## 11. Local data (SharedPreferences)

| Key (`PrefsKeys`) | Data |
|-------------------|------|
| `liked_songs` | Song persist IDs |
| `recently_played` | Ordered IDs |
| `theme_mode` | light / dark / system |
| `song_enrichment_v2` | JSON cache of genre + art URLs |
| `playlists` | User-created playlists JSON |
| `room_history` | Recent room codes |
| `listening_time_ms` | Total play time |
| `rooms_created` | Count for profile stat |
| `username`, `avatar_index` | Profile customization |

---

## 12. Firebase Analytics events

| Event | Trigger |
|-------|---------|
| `login` | Successful sign-in |
| `sign_up` | Registration |
| `song_played` | Track starts |
| `voice_command` | Voice command executed (parser: gemini/local) |
| `blend_calculated` | Blend screen result |
| `library_scan` | Scan completes |
| `library_enrichment` | Background enrichment batch (if logged) |

`FirebaseAnalyticsObserver` records screen navigation automatically.

---

## 13. Android permissions

| Permission | When |
|------------|------|
| `READ_MEDIA_AUDIO` (API 33+) | Library scan |
| `READ_EXTERNAL_STORAGE` (≤ API 32) | Library scan |
| `RECORD_AUDIO` | Voice tab |
| `INTERNET` | Firebase, Last.fm, Gemini |
| Foreground service / media playback | Background audio notification |

---

## 14. Console setup checklist (for evaluators)

### Firebase Console (`vynl-b454c`)

- [ ] Authentication: Email/Password + Google enabled  
- [ ] Realtime Database created (region: asia-southeast1)  
- [ ] Rules published from `database.rules.json`  
- [ ] Android app registered: `com.example.music_player`  
- [ ] SHA-1 fingerprint added (debug + release if needed)  
- [ ] Analytics dashboard visible  
- [ ] (Optional) Cloud Functions deployed on Blaze plan  

### Google AI Studio

- [ ] Create API key → paste as `GEMINI_API_KEY` in `.env`  

### Last.fm

- [ ] Create API account → Application key → `LASTFM_API_KEY` in `.env`  

### Google Cloud Console

- [ ] OAuth consent screen (usually auto via Firebase)  
- [ ] Android OAuth client matches package + SHA-1  

---

## 15. Known limitations (honest for report)

1. **Playback is local only** — no streaming catalog from the internet.  
2. **Album art/genre** load progressively as you scroll; not instant for entire library.  
3. **Blend** needs both users to have played songs while signed in.  
4. **iOS** Firebase options throw `UnsupportedError` — project is Android-focused.  
5. **`.env` in assets** — keys ship in the APK unless you use build flavors / obfuscation for production.  
6. **Room security** — any authenticated user can read/write any room node (suitable for coursework, not production).  

---

## 16. Project structure (folders)

```
lib/
├── main.dart
├── firebase_options.dart
├── core/           theme, routes, auth guard, permissions, colors
├── features/
│   ├── auth/       gate, screen, provider
│   ├── library/    scan, enrichment, playlists, liked
│   ├── now_playing/ vinyl, needle, full player
│   ├── social/     feed, blend
│   ├── rooms/      RTDB rooms UI + provider
│   ├── voice/      STT + Gemini + local parser
│   └── profile/    settings, stats
├── services/       analytics, gemini, enrichment, room codec, art cache
└── shared/         audio, theme, mini player, scaffold
```

---

## 17. Suggested report sections (copy to Word/PDF)

1. **Introduction** — Problem: local music players lack social + voice + metadata.  
2. **Objectives** — Playback, enrichment, Firebase social, voice AI, rooms.  
3. **Literature / related work** — Spotify social, Last.fm scrobbling, voice assistants.  
4. **System design** — Diagram from §7 + §8.  
5. **Implementation** — §9–§10.  
6. **Testing** — Two devices, two accounts, RTDB rules, scroll library for art.  
7. **Security** — §8 rules table.  
8. **Results** — Screenshots: Library, Now Playing, Social, Blend, Voice, Rooms.  
9. **Conclusion & future work** — iOS, stricter rules, Spotify integration, etc.  

---

## 18. Related documentation in this repo

| Document | Contents |
|----------|----------|
| `README.md` | Quick start, features, env vars |
| `docs/FIREBASE_SETUP.md` | Step-by-step Firebase + rules + Analytics |
| `docs/DEVICE_UPDATE_AND_TESTING.md` | How to install/update on phone and test enrichment |
| `functions/README.md` | Cloud Function deploy |

---

*Generated for academic project documentation. Update version numbers and screenshots before submission.*
