import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { db, getUserTokens, sendNotification } from "../helpers";
import { canReceiveAnnouncementNotification } from "./announcementLogic";

/**
 * Triggers when a new announcement is created.
 * Path: organizations/{orgId}/announcements/{announcementId}
 */
export const onAnnouncementCreated = onFirestoreCreated(
  "organizations/{orgId}/announcements/{announcementId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const title = (data.title as string) || "New Announcement";
    const authorName = (data.authorName as string) || "Someone";
    const scope = (data.scope as string) || "league";
    const isPinned = data.isPinned === true;

    const usersSnap = await db
      .collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .get();
    const recipientIds = usersSnap.docs
      .filter((user) => canReceiveAnnouncementNotification(user.data(), data))
      .map((user) => user.id);
    const tokens = await getUserTokens(recipientIds);

    await sendNotification(
      tokens,
      {
        title: isPinned ? `📌 ${title}` : title,
        body: `${authorName} posted a new ${scope} announcement`,
      },
      {
        type: "announcement",
        announcementId: event.params.announcementId,
        orgId,
      },
    );
  },
);
