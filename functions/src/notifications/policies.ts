import { DocumentData } from "firebase-admin/firestore";
import { onDocumentWritten as onFirestoreWritten } from "firebase-functions/v2/firestore";
import { getOrgTokens, sendNotification } from "../helpers";

export function isPolicyReady(data: DocumentData | undefined): boolean {
  return typeof data?.fileUrl === "string" && data.fileUrl.trim().length > 0 &&
    data.uploadStatus !== "uploading";
}

export function policyBecameReady(
  before: DocumentData | undefined,
  after: DocumentData | undefined,
): boolean {
  return !isPolicyReady(before) && isPolicyReady(after);
}

/**
 * Triggers when a new policy is uploaded.
 * Path: organizations/{orgId}/policies/{policyId}
 */
export const onPolicyCreated = onFirestoreWritten(
  "organizations/{orgId}/policies/{policyId}",
  async (event) => {
    const before = event.data?.before.data();
    const snapshot = event.data?.after;
    if (!snapshot?.exists) return;

    const data = snapshot.data();
    if (!data || !policyBecameReady(before, data)) return;
    const orgId = event.params.orgId;
    const policyName = (data.name as string) || "New Policy";
    const uploaderName = (data.uploadedByName as string) || "Someone";
    const category = (data.category as string) || "";

    const tokens = await getOrgTokens(orgId);

    await sendNotification(
      tokens,
      {
        title: "New Policy Uploaded",
        body: `${uploaderName} uploaded "${policyName}"${category ? ` in ${category}` : ""}`,
      },
      {
        type: "policy",
        policyId: event.params.policyId,
        orgId,
      },
    );
  },
);
