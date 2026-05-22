import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { getOrgTokens, sendNotification } from "../helpers";

/**
 * Triggers when a new policy is uploaded.
 * Path: organizations/{orgId}/policies/{policyId}
 */
export const onPolicyCreated = onFirestoreCreated(
  "organizations/{orgId}/policies/{policyId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
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
