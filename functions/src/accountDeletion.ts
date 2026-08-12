import * as admin from "firebase-admin";
import {CallableOptions, HttpsError, onCall} from "firebase-functions/v2/https";
import {
  accountAvatarPath,
  accountDeletionBlockedByOwnership,
  accountDeletionUserMatches,
  hasRecentAuthentication,
  isMissingAuthUserError,
} from "./accountDeletionLogic";
import {db} from "./helpers";

const runtime: CallableOptions = {
  region: "us-central1",
  timeoutSeconds: 120,
  memory: "512MiB",
};

async function removeOrganizationIdentity(userId: string, orgId: string): Promise<void> {
  const writer = db.bulkWriter();
  const teams = await db.collectionGroup("teams")
    .where("memberIds", "array-contains", userId)
    .get();
  for (const team of teams.docs) {
    if (team.data().orgId === orgId) {
      writer.update(team.ref, {
        memberIds: admin.firestore.FieldValue.arrayRemove(userId),
      });
    }
  }

  const orgRef = db.collection("organizations").doc(orgId);
  const rooms = await orgRef.collection("chatRooms").get();
  for (const room of rooms.docs) {
    const roomData = room.data();
    const participants = Array.isArray(roomData.participants) ?
      roomData.participants.filter((value) => value !== userId) : [];
    const participantNames = typeof roomData.participantNames === "object" &&
      roomData.participantNames !== null ? {...roomData.participantNames} : {};
    delete participantNames[userId];
    if (participants.length !== (roomData.participants ?? []).length) {
      writer.update(room.ref, {
        participants,
        participantNames,
        ...(roomData.type === "direct" ? {
          name: "Archived direct message",
          isArchived: true,
          roomImageUrl: null,
        } : {}),
      });
    }
    if (roomData.lastMessageSenderId === userId) {
      writer.update(room.ref, {
        lastMessageSenderId: "deleted-account",
        lastMessageBy: "Deleted Account",
      });
    }

    const authored = await room.ref.collection("messages")
      .where("senderId", "==", userId)
      .get();
    for (const message of authored.docs) {
      writer.update(message.ref, {
        senderId: "deleted-account",
        senderName: "Deleted Account",
        mediaUrl: null,
      });
    }
    const read = await room.ref.collection("messages")
      .where("readBy", "array-contains", userId)
      .get();
    for (const message of read.docs) {
      writer.update(message.ref, {
        readBy: admin.firestore.FieldValue.arrayRemove(userId),
      });
    }
  }

  const announcements = await orgRef.collection("announcements")
    .where("authorId", "==", userId)
    .get();
  for (const announcement of announcements.docs) {
    writer.update(announcement.ref, {
      authorId: "deleted-account",
      authorName: "Deleted Account",
    });
  }

  const policies = await orgRef.collection("policies")
    .where("uploadedBy", "==", userId)
    .get();
  for (const policy of policies.docs) {
    const versions = Array.isArray(policy.data().versions) ?
      policy.data().versions.map((version: Record<string, unknown>) => ({
        ...version,
        ...(version.uploadedBy === userId ? {
          uploadedBy: "deleted-account",
          uploadedByName: "Deleted Account",
        } : {}),
      })) : [];
    writer.update(policy.ref, {
      uploadedBy: "deleted-account",
      uploadedByName: "Deleted Account",
      versions,
    });
  }

  const submittedReports = await orgRef.collection("messageReports")
    .where("reporterId", "==", userId)
    .get();
  for (const report of submittedReports.docs) {
    writer.update(report.ref, {reporterId: "deleted-account"});
  }
  const receivedReports = await orgRef.collection("messageReports")
    .where("reportedUserId", "==", userId)
    .get();
  for (const report of receivedReports.docs) {
    writer.update(report.ref, {reportedUserId: "deleted-account"});
  }

  const blockers = await db.collection("users")
    .where("orgId", "==", orgId)
    .where("blockedUserIds", "array-contains", userId)
    .get();
  for (const blocker of blockers.docs) {
    writer.update(blocker.ref, {
      blockedUserIds: admin.firestore.FieldValue.arrayRemove(userId),
    });
  }

  await writer.close();
}

export const deleteOwnAccount = onCall(runtime, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Sign in before deleting your account.");
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!hasRecentAuthentication(request.auth?.token.auth_time, nowSeconds)) {
    throw new HttpsError(
      "failed-precondition",
      "Sign in again before deleting your account.",
    );
  }

  const userRef = db.collection("users").doc(userId);
  const snapshot = await userRef.get();
  const profile = snapshot.data();
  if (!accountDeletionUserMatches(userId, profile)) {
    throw new HttpsError("failed-precondition", "Your League Hub profile could not be verified.");
  }

  const orgId = typeof profile!.orgId === "string" ? profile!.orgId : null;
  if (orgId) {
    const orgSnapshot = await db.collection("organizations").doc(orgId).get();
    if (accountDeletionBlockedByOwnership(
      userId,
      profile!,
      orgSnapshot.data()?.ownerId,
    )) {
      throw new HttpsError(
        "failed-precondition",
        "Transfer league ownership before deleting this account.",
      );
    }
  }

  const avatarPath = accountAvatarPath(userId, profile!);
  if (avatarPath) {
    try {
      await admin.storage().bucket().file(avatarPath).delete({ignoreNotFound: true});
    } catch (error) {
      // A stale profile photo must not block deletion of the account itself.
      console.warn("Unable to remove account avatar", {userId, error});
    }
  }

  if (orgId) {
    await removeOrganizationIdentity(userId, orgId);
  }
  // Delete Auth first so a transient Auth failure leaves the intact profile
  // available for a safe retry. If the following profile delete fails, the
  // inaccessible orphaned profile can be removed through administrative
  // cleanup without leaving an authenticated, partially deleted account.
  try {
    await admin.auth().deleteUser(userId);
  } catch (error) {
    if (!isMissingAuthUserError(error)) throw error;
  }
  await userRef.delete();
  return {ok: true};
});
