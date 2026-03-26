import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getUserTokens, sendNotification } from "../helpers";

/**
 * Triggers when a user's document is updated and their role has changed.
 * Path: users/{userId}
 */
export const onUserRoleChanged = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const oldRole = before.role as string | undefined;
    const newRole = after.role as string | undefined;

    // Only fire when the role actually changed.
    if (!oldRole || !newRole || oldRole === newRole) return;

    const userId = event.params.userId;
    const displayName = (after.displayName as string) || "User";

    const roleLabels: Record<string, string> = {
      platformOwner: "Platform Owner",
      superAdmin: "Super Admin",
      managerAdmin: "Manager Admin",
      staff: "Staff",
    };

    const newRoleLabel = roleLabels[newRole] || newRole;

    const tokens = await getUserTokens([userId]);

    await sendNotification(
      tokens,
      {
        title: "Role Updated",
        body: `Your role has been changed to ${newRoleLabel}`,
      },
      {
        type: "role_changed",
        userId,
        newRole,
      },
    );
  },
);
