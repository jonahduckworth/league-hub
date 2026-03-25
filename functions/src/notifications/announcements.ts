import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { getOrgTokens, sendNotification } from "../helpers";

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
    const scope = (data.scope as string) || "orgWide";
    const isPinned = data.isPinned === true;

    const tokens = await getOrgTokens(orgId);

    await sendNotification(
      tokens,
      {
        title: isPinned ? `📌 ${title}` : title,
        body: `${authorName} posted a new ${scope === "orgWide" ? "organization-wide" : scope} announcement`,
      },
      {
        type: "announcement",
        announcementId: event.params.announcementId,
        orgId,
      },
    );
  },
);
