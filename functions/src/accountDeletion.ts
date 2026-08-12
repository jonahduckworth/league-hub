import * as admin from "firebase-admin";
import {CallableOptions, HttpsError, onCall} from "firebase-functions/v2/https";
import {accountAvatarPath, accountDeletionUserMatches} from "./accountDeletionLogic";
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

  await writer.close();
}

export const deleteOwnAccount = onCall(runtime, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Sign in before deleting your account.");
  }

  const userRef = db.collection("users").doc(userId);
  const snapshot = await userRef.get();
  const profile = snapshot.data();
  if (!accountDeletionUserMatches(userId, profile)) {
    throw new HttpsError("failed-precondition", "Your League Hub profile could not be verified.");
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

  if (typeof profile!.orgId === "string" && profile!.orgId.length > 0) {
    await removeOrganizationIdentity(userId, profile!.orgId);
  }
  await userRef.delete();
  await admin.auth().deleteUser(userId);
  return {ok: true};
});
