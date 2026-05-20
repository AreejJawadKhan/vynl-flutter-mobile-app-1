const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const HISTORY_LIMIT = 200;

/**
 * Trims listening history to the newest HISTORY_LIMIT entries after each write.
 */
exports.trimListeningHistory = functions.database
  .ref("/users/{uid}/listeningHistory/{entryId}")
  .onCreate(async (_snap, context) => {
    const uid = context.params.uid;
    const ref = admin.database().ref(`users/${uid}/listeningHistory`);

    const snapshot = await ref
      .orderByChild("timestamp")
      .limitToLast(HISTORY_LIMIT + 1)
      .once("value");

    if (!snapshot.exists()) {
      return null;
    }

    const entries = [];
    snapshot.forEach((child) => {
      const val = child.val() || {};
      entries.push({
        key: child.key,
        ts: typeof val.timestamp === "number" ? val.timestamp : 0,
      });
    });

    if (entries.length <= HISTORY_LIMIT) {
      return null;
    }

    entries.sort((a, b) => a.ts - b.ts);
    const excess = entries.length - HISTORY_LIMIT;
    const updates = {};
    for (let i = 0; i < excess; i++) {
      updates[entries[i].key] = null;
    }

    await ref.update(updates);
    functions.logger.info(
      `trimListeningHistory: removed ${excess} for uid=${uid}`,
    );
    return null;
  });
