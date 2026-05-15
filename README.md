# AI Music Player

**BS Computer Science — 6th Semester**  
**Mobile Applications Development — Mid-Semester Project**  
**40% Implementation Scope**

---

## Overview

An AI-powered music player for Android that combines local music library management with social listening rooms and on-device voice search. The application demonstrates core mobile development principles including reactive state management, custom animations, background audio processing, and permission handling — all without any external API or database.

---

## Features

### Library & Playback
- Scans device storage for all audio files using `on_audio_query`
- Real-time search and three sort modes (Title A–Z, Artist A–Z, Recently Added)
- Full playback controls: play, pause, next, previous, seek, shuffle, repeat (off / repeat-all / repeat-one)
- Background audio with lock screen controls and notification via `just_audio_background`
- Liked songs and recently played lists persisted to device storage

### Now Playing Screen
- Spinning vinyl record animation at 33⅓ RPM built with `CustomPainter`
- Tone-arm needle that swings onto the disc when playing and lifts when paused
- Four animation states: playing (constant spin), paused (decelerate), buffering (pulse glow), error (shake)
- Gesture control: tap to toggle play/pause, double-tap to like, swipe left/right to skip, long-press for song details

### Glassmorphic Mini-Player
- Persists above the bottom navigation bar on every screen
- Collapsed state (70px): album art, song title, artist, play/pause, next
- Expanded state (200px): full seek bar with live position, all controls, like button, mic shortcut
- Frosted glass effect using Flutter's `BackdropFilter` with 20px blur

### Group Listening Rooms
- Create a room with a generated 6-character alphanumeric code
- Configurable settings: who can add songs, majority vote vs host-only skip
- Simulated participants join automatically to demonstrate the full UI experience
- Song queue with per-item vote buttons (thumbs up/down), NOW PLAYING badge, vote progress bar
- Emoji reactions that float upward with fade animation
- In-room chat, participant avatars with active/away status indicator
- Room history (last 3 codes) persisted to device storage

### AI Voice Search
- Uses Android's on-device speech recognition — no cloud API required
- Six supported intents: play by mood, play by activity, play random, playback control, what's playing, like song
- Keyword maps for 5 moods (happy, sad, energetic, calm, focus) and 5 activities (workout, studying, relaxing, party, commute)
- Suggestion chips that simulate commands without using the microphone
- Animated sound wave visualiser during listening, command history (last 3)

### Profile
- Editable username and avatar with 8 pastel colour options
- Live stats: liked songs count, total library size, total listening time, rooms created
- Dark mode toggle and microphone permission status

---

## Technology Stack

| Concern | Package |
|---------|---------|
| Audio playback | `just_audio ^0.9.36` |
| Background audio | `just_audio_background ^0.0.1-beta.11` |
| Audio session management | `audio_session ^0.1.18` |
| Device library scan | `on_audio_query ^2.9.0` |
| State management | `provider ^6.1.1` |
| Local persistence | `shared_preferences ^2.2.2` |
| Permission handling | `permission_handler ^11.1.0` |
| Voice recognition | `speech_to_text ^6.6.0` |
| Typography | `google_fonts ^6.2.1` |

**No external API. No database. No cloud services.** All data is stored on-device via SharedPreferences.

---

## Project Structure

```
lib/
├── main.dart                            Entry point, MultiProvider, MaterialApp
│
├── core/                                Pure Dart — no Flutter widgets
│   ├── constants/
│   │   ├── app_colors.dart              Complete brand palette (30+ named constants)
│   │   ├── app_constants.dart           All dimensions, durations, limits
│   │   ├── app_routes.dart              Named route string constants
│   │   ├── app_text_styles.dart         All TextStyle getters via GoogleFonts
│   │   └── prefs_keys.dart              SharedPreferences key strings
│   ├── theme/
│   │   └── app_theme.dart               Full light + dark Material 3 ThemeData
│   └── utils/
│       ├── app_utils.dart               formatDuration, generateRoomCode
│       └── permission_helper.dart       Storage + microphone permission wrappers
│
├── features/
│   ├── library/
│   │   ├── library_screen.dart          Song list, search, sort
│   │   ├── models/song_model.dart       SongItem class, SortMode enum
│   │   ├── providers/library_provider.dart   Device scan, liked, recently played
│   │   └── widgets/
│   │       ├── album_art_widget.dart    Art thumbnail with placeholder fallback
│   │       ├── song_list_tile.dart      List row with animated equaliser bars
│   │       └── sort_bottom_sheet.dart   Sort picker modal (provider-safe)
│   │
│   ├── now_playing/
│   │   ├── now_playing_screen.dart      Full playback screen
│   │   └── widgets/
│   │       ├── vinyl_widget.dart        StatefulWidget owning 4 AnimationControllers
│   │       ├── vinyl_painter.dart       CustomPainter: disc, grooves, glint
│   │       └── needle_painter.dart      CustomPainter: pivoting tone-arm
│   │
│   ├── rooms/
│   │   ├── rooms_screen.dart            Lobby: create / join / history
│   │   ├── active_room_screen.dart      Live room: queue, chat, emoji
│   │   ├── models/room_models.dart      Room, Participant, QueueItem, etc.
│   │   ├── providers/room_provider.dart In-memory simulation engine
│   │   └── widgets/
│   │       ├── participant_avatar.dart  Pastel avatar with active dot
│   │       ├── queue_item_tile.dart     Queue row with vote buttons
│   │       ├── emoji_reaction_overlay.dart  Floating emoji animations
│   │       └── song_picker_sheet.dart   Pick song to add to queue
│   │
│   ├── voice/
│   │   ├── voice_screen.dart            Mic, wave, transcript, suggestions
│   │   ├── models/voice_models.dart     VoiceState, VoiceIntent, keyword maps
│   │   └── providers/voice_provider.dart   STT wrapper + intent parser
│   │
│   └── profile/
│       ├── profile_screen.dart          Avatar, username, stats, settings
│       └── providers/profile_provider.dart  Username + avatar persistence
│
└── shared/
    ├── providers/
    │   ├── audio_provider.dart          just_audio engine: full playback control
    │   └── theme_provider.dart          Light/dark toggle, persisted
    └── widgets/
        ├── main_scaffold.dart           Bottom nav + IndexedStack root shell
        ├── mini_player_stub.dart        Glassmorphic persistent mini-player
        ├── empty_state_widget.dart      Reusable empty/error state
        ├── app_snack_bar.dart           Consistent snackbar helper
        └── widgets.dart                 Barrel export
```

---

## State Management Architecture

The app uses **Provider** for state management. All providers are declared at the root `MultiProvider` in `main.dart` in dependency order:

```
ThemeProvider           (standalone)
    └── LibraryProvider (standalone — scans device on creation)
            └── AudioProvider (ProxyProvider: needs LibraryProvider to record plays)
                    └── RoomProvider (ProxyProvider: needs AudioProvider to trigger playback)
                    └── VoiceProvider (ProxyProvider2: needs both Audio + Library)
ProfileProvider         (standalone)
```

`ChangeNotifierProxyProvider` is used where Provider B needs a reference to Provider A. The `update` callback injects the latest instance of A into B every time A changes.

Modal bottom sheets use `ChangeNotifierProvider.value` to re-inject the needed provider into the new route context, since modal routes run in an overlay disconnected from the main provider tree.

---

## Data Persistence

All data is stored on-device via `SharedPreferences`. No database, no cloud sync.

| Key | Type | Contents |
|-----|------|----------|
| `liked_songs` | `List<String>` | Song IDs of liked tracks |
| `recently_played` | `List<String>` | Song IDs, newest first (max 20) |
| `theme_mode` | `String` | `'light'`, `'dark'`, or `'system'` |
| `room_history` | `List<String>` | Last 3 room codes |
| `rooms_created` | `int` | Total rooms created |
| `listening_time_ms` | `int` | Cumulative playback in milliseconds |
| `username` | `String` | Display name |
| `avatar_index` | `int` | Selected colour index (0–7) |

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.1.0
- Android Studio with Flutter and Dart plugins
- Android device or emulator running API 21+ (Android 5.0+)

### Setup

```bash
# 1. Create a Flutter project skeleton (provides gradle wrapper, icons, etc.)
flutter create --org com.example --project-name music_player music_player

# 2. Replace the generated lib/ and config files with this project's files
#    (see architecture above for which files go where)

# 3. Create empty asset directories
mkdir -p assets/images assets/icons

# 4. Install dependencies
flutter pub get

# 5. Run on a connected Android device or emulator
flutter run
```

Grant **storage permission** on first launch for the library scan.  
Grant **microphone permission** when using AI Voice Search.


---

## Android Permissions

| Permission | Purpose |
|-----------|---------|
| `READ_MEDIA_AUDIO` (API 33+) | Read audio files from device storage |
| `READ_EXTERNAL_STORAGE` (API ≤ 32) | Read audio files on older Android versions |
| `RECORD_AUDIO` | AI voice search microphone access |
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Lock screen and notification controls |
| `WAKE_LOCK` | Keep CPU active during background playback |
| `VIBRATE` | Haptic feedback on controls |

---

## Design System

**Color Palette** — all values defined in `AppColors`, no hardcoded hex anywhere else:

| Token | Hex | Usage |
|-------|-----|-------|
| `darkBerry` | `#7D0531` | Primary buttons, active states, selected tab |
| `roseQuartz` | `#B05276` | Secondary buttons, like heart, gradients |
| `blush` | `#DBBABF` | Page backgrounds, card fills |
| `sage` | `#75824D` | AI mic button, success states, CTA |
| `stone` | `#C1BEB9` | Secondary text, borders, disabled icons |

**Typography** — `GoogleFonts.poppins()` throughout, `GoogleFonts.robotoMono()` for room codes.  
**Spacing** — 8px grid: `spaceXS(4)` → `spaceS(8)` → `spaceM(16)` → `spaceL(24)` → `spaceXL(32)`.

---

## Known Limitations (Scope Boundaries)

- **Rooms are simulated.** There is no real-time network. Participants are injected by `Timer` objects inside `RoomProvider`. The room model, queue logic, and voting system are fully implemented and could be connected to a WebSocket or Firebase backend by replacing only the private simulation methods.
- **Voice search requires Android's speech engine.** The first use on some devices may require a brief internet connection to download the language model. After that it operates fully offline.
- **No user authentication.** The local user is always the room host in simulation mode.
- **Album art in lock screen notification** does not display. The `MediaItem` tag in `AudioProvider` does not yet resolve artwork bytes from `on_audio_query`.

---

## Out of Scope- for now

Cloud database, user authentication, internet music streaming, real friend lists, music downloading, push notifications, analytics, and advanced ML models.

