import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { db, getUserTokens, sendNotification } from "../helpers";

type UserData = {
  role?: string;
  hubIds?: string[];
  leagueIds?: string[];
};

const elevatedRoles = new Set(["platformOwner", "superAdmin"]);

function hasId(values: unknown, id: string): boolean {
  return Array.isArray(values) && values.includes(id);
}

function canReceiveOpenRoomNotification(
  user: UserData,
  roomType: string,
  hubId?: string,
  leagueId?: string,
): boolean {
  if (elevatedRoles.has(user.role ?? "")) return true;
  if (roomType === "event") return true;
  if (roomType !== "league") return false;

  if (hubId) return hasId(user.hubIds, hubId);
  if (leagueId) return hasId(user.leagueIds, leagueId);

  return true;
}

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
    const hubId = roomData.hubId as string | undefined;
    const leagueId = roomData.leagueId as string | undefined;

    // Explicit participants win. Open rooms use the same room visibility
    // criteria as Firestore rules so scoped rooms do not notify outsiders.
    let recipientIds: string[];

    if (roomType === "direct" && participants.length === 2) {
      recipientIds = participants.filter((id) => id !== senderId);
    } else if (participants.length > 0) {
      recipientIds = participants.filter((id) => id !== senderId);
    } else {
      const usersSnap = await db
        .collection("users")
        .where("orgId", "==", orgId)
        .where("isActive", "==", true)
        .get();
      recipientIds = usersSnap.docs
        .filter((d) =>
          canReceiveOpenRoomNotification(
            d.data() as UserData,
            roomType,
            hubId,
            leagueId,
          ),
        )
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
