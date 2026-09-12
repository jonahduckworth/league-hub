import * as admin from "firebase-admin";
import {db, NotificationDeliveryGroup} from "../helpers";

export type UnreadChatNotificationTarget = {
  userId: string;
  tokens: string[];
  badgeCount?: number;
};

function storedCount(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ?
    value : 0;
}

function storedIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((id): id is string =>
    typeof id === "string" && id.length > 0))];
}

export function unreadRecipientIds(
  recipientIds: string[],
  readBy: unknown,
): string[] {
  const readers = new Set(storedIds(readBy));
  return [...new Set(recipientIds)]
    .filter((id) => id.length > 0 && !readers.has(id));
}

export function unreadChatDeliveryGroups(
  targets: UnreadChatNotificationTarget[],
): NotificationDeliveryGroup[] {
  const grouped = new Map<string, NotificationDeliveryGroup>();
  for (const target of targets) {
    const badge = target.badgeCount;
    const key = badge === undefined ? "none" : `badge-${badge}`;
    const group = grouped.get(key) ?? {tokens: [], badge};
    group.tokens.push(...target.tokens);
    grouped.set(key, group);
  }
  return [...grouped.values()];
}

function roomUnreadRef(orgId: string, roomId: string, userId: string) {
  return db.collection("organizations").doc(orgId)
    .collection("chatRooms").doc(roomId)
    .collection("unreadCounts").doc(userId);
}

export async function initializeUnreadChatAccounting(
  messageRef: admin.firestore.DocumentReference,
  orgId: string,
  roomId: string,
  recipientIds: string[],
): Promise<UnreadChatNotificationTarget[]> {
  return db.runTransaction(async (transaction) => {
    const message = await transaction.get(messageRef);
    if (!message.exists) return [];

    const initialized = message.get("unreadAccountingInitialized") === true;
    const unreadIds = initialized ?
      storedIds(message.get("unreadRecipientIds")) :
      unreadRecipientIds(recipientIds, message.get("readBy"));
    const userRefs = unreadIds.map((id) => db.collection("users").doc(id));
    const countRefs = unreadIds.map((id) => roomUnreadRef(orgId, roomId, id));
    const userDocs = userRefs.length > 0 ?
      await transaction.getAll(...userRefs) : [];
    const countDocs = countRefs.length > 0 ?
      await transaction.getAll(...countRefs) : [];

    const accountedIds: string[] = [];
    const targets: UnreadChatNotificationTarget[] = [];
    for (let index = 0; index < unreadIds.length; index++) {
      const user = userDocs[index];
      if (!user.exists || user.get("isActive") === false ||
          user.get("orgId") !== orgId) continue;
      const userId = unreadIds[index];
      const previousTotal = storedCount(user.get("unreadChatCount"));
      const previousRoomCount = storedCount(
        countDocs[index].exists ? countDocs[index].get("count") : undefined,
      );
      const total = previousTotal + (initialized ? 0 : 1);
      if (!initialized) {
        transaction.set(
          userRefs[index],
          {unreadChatCount: total},
          {merge: true},
        );
        transaction.set(countRefs[index], {
          count: previousRoomCount + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      accountedIds.push(userId);
      targets.push({
        userId,
        tokens: storedIds(user.get("fcmTokens")),
        badgeCount: user.get("appBadgeEnabled") === false ? undefined : total,
      });
    }

    if (!initialized) {
      transaction.update(messageRef, {
        unreadAccountingInitialized: true,
        unreadRecipientIds: accountedIds,
      });
    }
    return targets;
  });
}

async function decrementUnreadCounts(
  orgId: string,
  roomId: string,
  candidateIds: string[],
  messageRef?: admin.firestore.DocumentReference,
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    let pendingIds = [...new Set(candidateIds)];
    let currentPendingIds: string[] | null = null;
    if (messageRef != null) {
      const message = await transaction.get(messageRef);
      if (!message.exists) return;
      currentPendingIds = storedIds(message.get("unreadRecipientIds"));
      const currentlyPending = new Set(currentPendingIds);
      pendingIds = pendingIds.filter((id) => currentlyPending.has(id));
    }
    if (pendingIds.length === 0) return;

    const userRefs = pendingIds.map((id) => db.collection("users").doc(id));
    const countRefs = pendingIds.map((id) => roomUnreadRef(orgId, roomId, id));
    const userDocs = await transaction.getAll(...userRefs);
    const countDocs = await transaction.getAll(...countRefs);

    for (let index = 0; index < pendingIds.length; index++) {
      if (!userDocs[index].exists) continue;
      const total = storedCount(userDocs[index].get("unreadChatCount"));
      const roomCount = storedCount(
        countDocs[index].exists ? countDocs[index].get("count") : undefined,
      );
      transaction.set(userRefs[index], {
        unreadChatCount: Math.max(0, total - (roomCount > 0 ? 1 : 0)),
      }, {merge: true});
      transaction.set(countRefs[index], {
        count: Math.max(0, roomCount - 1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    if (messageRef != null) {
      const removed = new Set(pendingIds);
      const remaining = (currentPendingIds ?? [])
        .filter((id) => !removed.has(id));
      transaction.update(messageRef, {unreadRecipientIds: remaining});
    }
  });
}

export async function markUnreadChatMessageRead(
  messageRef: admin.firestore.DocumentReference,
  orgId: string,
  roomId: string,
  newReaderIds: string[],
): Promise<void> {
  return decrementUnreadCounts(orgId, roomId, newReaderIds, messageRef);
}

export async function removeDeletedUnreadChatMessage(
  orgId: string,
  roomId: string,
  unreadIds: unknown,
): Promise<void> {
  return decrementUnreadCounts(orgId, roomId, storedIds(unreadIds));
}
