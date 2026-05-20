# Updating Vynl on your phone (and loading album art / genres)

Use this when an **older build** is already on your phone and you want the **latest code** with Last.fm art, genres, Firebase social, etc.

---

## Hot restart (`R`) — what it actually does

| Action | Key | What happens |
|--------|-----|----------------|
| **Hot reload** | `r` | Updates Dart UI code only. Does **not** re-run `main()`, does **not** reload `.env`, does **not** reinstall the APK. |
| **Hot restart** | `R` (Shift+R) | Restarts the Dart VM: re-runs `main()`, providers re-init, library may re-scan. Still the **same installed APK** on the phone. |
| **Full update** | Quit + `flutter run` | Builds and installs a **new APK** over the old app. **Use this** when you changed dependencies, `pubspec.yaml`, native Android code, `google-services.json`, or assets like `.env`. |

**Bottom line:** If the app on your phone was installed days ago from an old `flutter run`, pressing **`R` alone is not enough**. You need a fresh **`flutter run`** to that device (or uninstall first).

---

## Recommended: full update on your physical phone

### 1. Prepare the project (once per machine)

```powershell
cd C:\Users\Faryal\AndroidStudioProjects\Vynl
flutter pub get
```

Ensure **`.env`** exists in the project root (copy from `.env.example`):

```env
LASTFM_API_KEY=your_lastfm_key_here
GEMINI_API_KEY=your_gemini_key_here
```

Without `LASTFM_API_KEY`, genres use guesses only and album art URLs stay empty.

### 2. Connect the phone

- Enable **Developer options** → **USB debugging**
- Plug in USB, accept the debugging prompt
- Verify device:

```powershell
flutter devices
```

You should see your phone (not only the emulator).

### 3. Stop old debug sessions

- In the terminal where Flutter is running, press **`q`** to quit
- Or close the old run from Android Studio

### 4. Install the latest build on the phone

```powershell
flutter run -d <your-phone-device-id>
```

Example if only one phone is connected:

```powershell
flutter run
```

When prompted, pick your **physical device**, not the emulator.

This **replaces** the installed `com.example.music_player` app with the new debug build.

### 5. Optional: clean install (if something still looks “old”)

```powershell
adb uninstall com.example.music_player
flutter run
```

You will need to **sign in again** and re-grant permissions. Local likes/recents prefs are cleared.

---

## After install: make album art and genres appear

Enrichment is **lazy** — it does not fetch every song at launch.

1. **Sign in** (Google or email) — Firebase `songMeta` cache only loads when authenticated.
2. Open **Library** tab → allow **music / storage** permission when asked.
3. Wait for the library scan to finish (spinner stops).
4. **Scroll slowly** through the song list — each visible row triggers Last.fm lookup (max 4 at a time).
5. Pull down to refresh is not required for art; scrolling is what matters.
6. Second launch: cached art/genre from SharedPreferences + Firebase loads faster.

**Hot restart (`R`) after `.env` was added:**  
If you added `LASTFM_API_KEY` while `flutter run` was already active, press **`R`** once so `main()` reloads dotenv — or safer, **`q`** then `flutter run` again.

---

## When to use hot restart (`R`) during development

Use **`R`** when you changed **Dart code only** (UI, providers logic) and want a fresh app state without reinstalling:

- After editing social/blend/voice screens
- After fixing a provider bug
- To force library re-scan without quitting (LibraryProvider runs `scanLibrary()` on create)

Do **not** rely on **`R`** for:

- New packages in `pubspec.yaml` → run `flutter pub get` then full `flutter run`
- Changed `.env` (first time) → full `flutter run` recommended
- New `google-services.json` → full `flutter run`
- Android manifest / permissions → full `flutter run`

---

## Quick reference (terminal while `flutter run` is active)

| Key | Action |
|-----|--------|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Quit |
| `h` | Help |

---

## Verify everything works on the phone

| Check | How |
|-------|-----|
| Auth | Sign in with Google or email |
| Library | Songs listed after storage permission |
| Album art | Scroll library; art appears on rows over ~5–30 s |
| Playback | Tap song; mini-player plays |
| Social | Second device/emulator, other account, play song → appears on Social tab |
| Voice | Mic permission; say “pause” or “play rock” |
| Firebase | Console → RTDB → see `users/{uid}`, `nowPlaying/{uid}` after play |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Still old UI after `R` | `q` → `flutter run` on phone |
| No album art | Add `LASTFM_API_KEY` to `.env`, reinstall, scroll library |
| `permission-denied` in logs | Publish `database.rules.json` in Firebase Console |
| Google Sign-In fails on phone | Add phone’s SHA-1 to Firebase; update `google-services.json` |
| Wrong device updated | `flutter devices` then `flutter run -d <id>` |

See also: [FIREBASE_SETUP.md](FIREBASE_SETUP.md), [PROJECT_REPORT.md](PROJECT_REPORT.md).
