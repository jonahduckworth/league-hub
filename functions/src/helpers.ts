import * as admin from "firebase-admin";

// Initialize once.
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const messaging = admin.messaging();

/**
 * Fetches all FCM tokens for users in an organization.
 * Tokens are stored in /users/{uid} → fcmTokens: string[]
 */
export async function getOrgTokens(orgId: string): Promise<string[]> {
  const usersSnap = await db
    .collection("users")
    .where("orgId", "==", orgId)
    .where("isActive", "==", true)
    .get();

  const tokens: string[] = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const userTokens = data.fcmTokens as string[] | undefined;
    if (userTokens && userTokens.length > 0) {
      tokens.push(...userTokens);
    }
  }
  return tokens;
}

/**
 * Fetches FCM tokens for a specific list of user IDs.
 */
export async function getUserTokens(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];

  // Firestore `in` queries support max 30 items at a time.
  const tokens: string[] = [];
  const chunks = chunkArray(userIds, 30);
  for (const chunk of chunks) {
    const snap = await db
      .collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", chunk)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const userTokens = data.fcmTokens as string[] | undefined;
      if (userTokens && userTokens.length > 0) {
        tokens.push(...userTokens);
      }
    }
  }
  return tokens;
}

/**
 * Sends an FCM notification to a list of tokens, handling stale token cleanup.
 */
export async function sendNotification(
  tokens: string[],
  notification: { title: string; body: string },
  data: Record<string, string>,
): Promise<void> {
  if (tokens.length === 0) return;

  // Deduplicate tokens.
  const uniqueTokens = [...new Set(tokens)];

  // FCM multicast supports max 500 tokens per call.
  const chunks = chunkArray(uniqueTokens, 500);

  for (const chunk of chunks) {
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification,
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "league_hub_default",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Clean up stale tokens.
    if (response.failureCount > 0) {
      const staleTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (resp.error) {
          const code = resp.error.code;
          if (
            code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered"
          ) {
            staleTokens.push(chunk[idx]);
          }
        }
      });

      if (staleTokens.length > 0) {
        await removeStaleTokens(staleTokens);
      }
    }
  }
}

/**
 * Removes stale FCM tokens from all users who have them.
 */
async function removeStaleTokens(tokens: string[]): Promise<void> {
  for (const token of tokens) {
    const usersSnap = await db
      .collection("users")
      .where("fcmTokens", "array-contains", token)
      .get();

    const batch = db.batch();
    for (const doc of usersSnap.docs) {
      batch.update(doc.ref, {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
      });
    }
    await batch.commit();
  }
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
