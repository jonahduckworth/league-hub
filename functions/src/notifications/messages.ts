import {onDocumentCreated as onFirestoreCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {db, sendNotificationGroups} from "../helpers";
import {
  canReceiveMessageNotification,
  chatNotificationDeliveryGroups,
  MessageNotificationUser,
  notificationLookupIds,
  participantLookupBatches,
  shouldUseExplicitParticipantRecipients,
  shouldReplaceRoomPreview,
  visibleRoomPreview,
} from "./messageLogic";


/**
 * Triggers when a new message is sent in a chat room.
 * Path: organizations/{orgId}/chatRooms/{roomId}/messages/{messageId}
 */
export const onMessageCreated = onFirestoreCreated(
  "organizations/{orgId}/chatRooms/{roomId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const roomId = event.params.roomId;
    const senderId = data.senderId as string;
    const senderName = (data.senderName as string) || "Someone";
    const text = (data.text as string) || "";
    const previewText = (data.previewText as string) || text || "Attachment";

    // Get the chat room to find participants and room name.
    const roomSnap = await db
      .collection("organizations")
      .doc(orgId)
      .collection("chatRooms")
      .doc(roomId)
      .get();

    if (!roomSnap.exists) return;

    // Re-read immediately before recipient selection so a concurrent room
    // scope change cannot notify users under stale, broader metadata.
    const currentRoomSnap = await roomSnap.ref.get();
    if (!currentRoomSnap.exists) return;
    const roomData = currentRoomSnap.data()!;
    const roomName = (roomData.name as string) || "Chat";
    const participants = (roomData.participants as string[]) || [];
    const roomType = (roomData.type as string) || "league";
    const accessMode = roomData.accessMode as string | undefined;
    const hubId = roomData.hubId as string | undefined;
    const leagueId = roomData.leagueId as string | undefined;
    const teamId = roomData.teamId as string | undefined;
    const hubIds = Array.isArray(roomData.hubIds) ? roomData.hubIds as string[] : [];
    const teamIds = Array.isArray(roomData.teamIds) ? roomData.teamIds as string[] : [];
    const additionalMemberIds = Array.isArray(roomData.additionalMemberIds) ?
      roomData.additionalMemberIds as string[] : [];

    // Explicit participants win. Open rooms use the same room visibility
    // criteria as Firestore rules so scoped rooms do not notify outsiders.
    let recipientUsers: MessageNotificationUser[];

    if (shouldUseExplicitParticipantRecipients(
      participants,
      teamIds,
      accessMode,
    )) {
      const lookupIds = notificationLookupIds(
        participants,
        additionalMemberIds,
        roomType,
        accessMode,
      );
      const participantUsers = await Promise.all(
        participantLookupBatches(lookupIds).map((ids) =>
          db.collection("users")
            .where(admin.firestore.FieldPath.documentId(), "in", ids)
            .get(),
        ),
      );
      recipientUsers = participantUsers.flatMap((snapshot) => snapshot.docs)
        .filter((user) => user.id !== senderId)
        .filter((user) => canReceiveMessageNotification(
          user.data(), senderId, roomType, hubId, leagueId, orgId, teamId,
          hubIds, teamIds, additionalMemberIds, user.id, accessMode,
        ))
        .map((user) => user.data());
    } else {
      const usersSnap = await db
        .collection("users")
        .where("orgId", "==", orgId)
        .where("isActive", "==", true)
        .get();
      recipientUsers = usersSnap.docs
        .filter((d) =>
          canReceiveMessageNotification(
            d.data(),
            senderId,
            roomType,
            hubId,
            leagueId,
            orgId,
            teamId,
            hubIds,
            teamIds,
            additionalMemberIds,
            d.id,
          ),
        )
        .filter((d) => d.id !== senderId)
        .map((d) => d.data());
    }

    // Truncate message preview.
    const preview = previewText.length > 100 ?
      previewText.substring(0, 97) + "..." : previewText;

    await sendNotificationGroups(
      chatNotificationDeliveryGroups(recipientUsers),
      {
        title: roomType === "direct" ? senderName : roomName,
        body: roomType === "direct" ? preview : `${senderName}: ${preview}`,
      },
      {
        type: "chat_message",
        roomId,
        orgId,
      },
    );
  },
);

export const onMessagePreviewCreated = onFirestoreCreated(
  {
    document: "organizations/{orgId}/chatRooms/{roomId}/messages/{messageId}",
    retry: true,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
    if (!createdAt) return;
    const senderId = data.senderId as string;
    const senderName = (data.senderName as string) || "Someone";
    const text = (data.text as string) || "";
    const previewText = (data.previewText as string) || text || "Attachment";
    const roomRef = db.collection("organizations")
      .doc(event.params.orgId)
      .collection("chatRooms")
      .doc(event.params.roomId);

    await db.runTransaction(async (transaction) => {
      const room = await transaction.get(roomRef);
      if (!room.exists) return;
      const current = room.data()!;
      const currentTime = current.lastMessageAt instanceof admin.firestore.Timestamp ?
        current.lastMessageAt.toMillis() : null;
      if (!shouldReplaceRoomPreview(
        currentTime,
        typeof current.lastMessageId === "string" ? current.lastMessageId : null,
        createdAt.toMillis(),
        snapshot.id,
      )) return;
      const visiblePreview = visibleRoomPreview(
        current.accessMode,
        senderName,
        senderId,
        previewText,
      );
      transaction.update(roomRef, {
        ...visiblePreview,
        lastMessageAt: createdAt,
        lastMessageId: snapshot.id,
      });
    });
  },
);
