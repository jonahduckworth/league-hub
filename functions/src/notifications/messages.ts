import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { db, getUserTokens, sendNotification } from "../helpers";

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

    // Get the chat room to find participants and room name.
    const roomSnap = await db
      .collection("organizations")
      .doc(orgId)
      .collection("chatRooms")
      .doc(roomId)
      .get();

    if (!roomSnap.exists) return;

    const roomData = roomSnap.data()!;
    const roomName = (roomData.name as string) || "Chat";
    const participants = (roomData.participants as string[]) || [];
    const roomType = (roomData.type as string) || "league";

    // For DMs, notify the other participant. For group chats, notify all except sender.
    let recipientIds: string[];

    if (roomType === "direct" && participants.length === 2) {
      recipientIds = participants.filter((id) => id !== senderId);
    } else if (participants.length > 0) {
      recipientIds = participants.filter((id) => id !== senderId);
    } else {
      // Open room — notify all org members except sender.
      const usersSnap = await db
        .collection("users")
        .where("orgId", "==", orgId)
        .where("isActive", "==", true)
        .get();
      recipientIds = usersSnap.docs
        .map((d) => d.id)
        .filter((id) => id !== senderId);
    }

    const tokens = await getUserTokens(recipientIds);

    // Truncate message preview.
    const preview = text.length > 100 ? text.substring(0, 97) + "..." : text;

    await sendNotification(
      tokens,
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
