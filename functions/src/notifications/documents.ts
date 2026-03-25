import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { getOrgTokens, sendNotification } from "../helpers";

/**
 * Triggers when a new document is uploaded.
 * Path: organizations/{orgId}/documents/{documentId}
 */
export const onDocumentCreated = onFirestoreCreated(
  "organizations/{orgId}/documents/{documentId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const docName = (data.name as string) || "New Document";
    const uploaderName = (data.uploadedByName as string) || "Someone";
    const category = (data.category as string) || "";

    const tokens = await getOrgTokens(orgId);

    await sendNotification(
      tokens,
      {
        title: "New Document Uploaded",
        body: `${uploaderName} uploaded "${docName}"${category ? ` in ${category}` : ""}`,
      },
      {
        type: "document",
        documentId: event.params.documentId,
        orgId,
      },
    );
  },
);
