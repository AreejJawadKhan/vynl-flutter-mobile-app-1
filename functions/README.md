# Vynl Cloud Functions

## Prerequisites

- Firebase project on **Blaze** plan (required for Cloud Functions)
- Node.js 20+
- Firebase CLI: `npm install -g firebase-tools`

## Deploy

From the **repository root** (parent of `functions/`):

```bash
firebase login
firebase use vynl-b454c
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Functions

| Name | Trigger | Purpose |
|------|---------|---------|
| `trimListeningHistory` | RTDB `onCreate` on `users/{uid}/listeningHistory/{entryId}` | Keeps at most 200 history entries per user |

## Verify

1. Firebase Console → **Functions** — `trimListeningHistory` should appear
2. Play songs in the app while signed in
3. RTDB → `users/{uid}/listeningHistory` should not grow beyond ~200 entries
