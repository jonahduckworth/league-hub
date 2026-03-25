import { onDocumentCreated as onFirestoreCreated } from "firebase-functions/v2/firestore";
import { db, sendNotification } from "../helpers";

/**
 * Triggers when a new invitation is created.
 * Path: organizations/{orgId}/invitations/{invitationId}
 *
 * Sends a notification to the invitee if they already have an account,
 * and notifies org admins about the new invitation.
 */
export const onInvitationCreated = onFirestoreCreated(
  "organizations/{orgId}/invitations/{invitationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const orgId = event.params.orgId;
    const inviteeEmail = (data.email as string) || "";
    const inviteeName = (data.displayName as string) || inviteeEmail;
    const invitedByName = (data.invitedByName as string) || "Someone";

    // Notify admins in the org about the new invitation.
    const adminsSnap = await db
      .collection("users")
      .where("orgId", "==", orgId)
      .where("isActive", "==", true)
      .where("role", "in", ["platformOwner", "superAdmin"])
      .get();

    const adminTokens: string[] = [];
    for (const doc of adminsSnap.docs) {
      const userData = doc.data();
      const tokens = userData.fcmTokens as string[] | undefined;
      if (tokens && tokens.length > 0) {
        adminTokens.push(...tokens);
      }
    }

    if (adminTokens.length > 0) {
      await sendNotification(
        adminTokens,
        {
          title: "New Invitation Sent",
          body: `${invitedByName} invited ${inviteeName} to join the organization`,
        },
        {
          type: "invitation",
          orgId,
        },
      );
    }

    // If the invitee already has an account, notify them too.
    const existingUserSnap = await db
      .collection("users")
      .where("email", "==", inviteeEmail)
      .limit(1)
      .get();

    if (!existingUserSnap.empty) {
      const existingUser = existingUserSnap.docs[0].data();
      const userTokens = existingUser.fcmTokens as string[] | undefined;
      if (userTokens && userTokens.length > 0) {
        await sendNotification(
          userTokens,
          {
            title: "You've Been Invited!",
            body: `${invitedByName} has invited you to join their organization`,
          },
          {
            type: "invitation_received",
            orgId,
          },
        );
      }
    }
  },
);
