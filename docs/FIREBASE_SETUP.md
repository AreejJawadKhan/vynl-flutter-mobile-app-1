# Firebase setup for Vynl

Project ID: **vynl-b454c** (see `android/app/google-services.json` and `lib/firebase_options.dart`).

---

## Part A — Enable sign-in providers

### 1. Open Firebase Console

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Select project **vynl-b454c**

### 2. Enable Email/Password

1. Left menu: **Build** → **Authentication**
2. Tab: **Sign-in method**
3. Click **Email/Password**
4. Turn **Enable** ON
5. (Optional) Enable **Email link** only if you plan to use it — Vynl uses password auth
6. Click **Save**

### 3. Enable Google Sign-In

1. Still on **Authentication** → **Sign-in method**
2. Click **Google**
3. Turn **Enable** ON
4. Set **Project support email** (your Google account)
5. Click **Save**

### 4. Android SHA-1 (required for Google Sign-In on device)

1. In project root terminal:

   ```bash
   cd android
   ./gradlew signingReport
   ```

   On Windows:

   ```powershell
   cd android
   .\gradlew signingReport
   ```

2. Copy **SHA-1** under `Variant: debug` (and `release` if you ship release builds)
3. Firebase Console → **Project settings** (gear) → **Your apps** → Android app `com.example.music_player`
4. Click **Add fingerprint**, paste SHA-1, **Save**
5. Re-download `google-services.json` if prompted and replace `android/app/google-services.json`

### 5. Authorized domains (web / email links)

1. **Authentication** → **Settings** → **Authorized domains**
2. Ensure `localhost` and your production domain are listed if you use web builds

---

## Part B — Realtime Database + rules

### 1. Create or open Realtime Database

1. **Build** → **Realtime Database**
2. If no database exists: **Create Database**
3. Choose region (e.g. `us-central1`)
4. Start in **locked mode** (you will paste rules next)

### 2. Deploy `database.rules.json`

**Option 1 — Firebase Console (no CLI)**

1. Open **Realtime Database** → **Rules**
2. Open `database.rules.json` from this repo in an editor
3. Copy the entire JSON
4. Paste into the Console rules editor
5. Click **Publish**

**Option 2 — Firebase CLI**

1. Install CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. In project root (where `database.rules.json` lives):

   ```bash
   firebase use vynl-b454c
   firebase deploy --only database
   ```

### 3. Verify rules

In **Rules** tab you should see:

- Root `.read` / `.write`: `false`
- `nowPlaying`: read if `auth != null` (required to list the live feed)
- `nowPlaying/{uid}`: write only own uid
- `users/{uid}`: read/write own profile; `listeningHistory` writable by owner
- `rooms`: read/write for any signed-in user (join flow reads the room before adding a participant)
- `songMeta`: read/write for any signed-in user (shared cache)

### 4. Test in Console

1. **Realtime Database** → **Data**
2. After signing in on the app, you should see nodes like `users/{uid}`, `nowPlaying/{uid}`
3. If writes fail, check **Authentication** is enabled and rules are published

---

## Part C — Analytics

1. **Build** → **Analytics** → **Dashboard**
2. Analytics is enabled by default when the Firebase Android app is linked
3. Debug events on device:

   ```bash
   adb shell setprop debug.firebase.analytics.app com.example.music_player
   ```

4. Disable after testing:

   ```bash
   adb shell setprop debug.firebase.analytics.app .none.
   ```

---

## Part D — Cloud Functions (listening history trim)

See `functions/README.md` in this repo.

Summary:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Requires **Blaze** (pay-as-you-go) plan for Cloud Functions. Spark plan cannot deploy functions.

---

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `permission-denied` on RTDB | Publish `database.rules.json`; user must be signed in |
| Google Sign-In fails on phone | Add SHA-1 fingerprint; update `google-services.json` |
| `network-request-failed` | Device internet; check Firebase project region |
| Social feed empty | Publish rules (parent `nowPlaying` must be readable); two different accounts playing songs |
| Functions not trimming history | Deploy functions; upgrade to Blaze plan |
