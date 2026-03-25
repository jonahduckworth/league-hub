import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getOrgTokens, sendNotification } from "../helpers";

/**
 * Triggers when a team document is created, updated, or deleted.
 * Path: organizations/{orgId}/leagues/{leagueId}/hubs/{hubId}/teams/{teamId}
 */
export const onTeamUpdated = onDocumentWritten(
  "organizations/{orgId}/leagues/{leagueId}/hubs/{hubId}/teams/{teamId}",
  async (event) => {
    const orgId = event.params.orgId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    let title: string;
    let body: string;

    if (!before && after) {
      // Created
      title = "New Team Added";
      body = `Team "${after.name || "Unknown"}" has been added`;
    } else if (before && !after) {
      // Deleted
      title = "Team Removed";
      body = `Team "${before.name || "Unknown"}" has been removed`;
    } else if (before && after) {
      // Updated — only notify on meaningful changes
      if (before.name === after.name) return; // No name change, skip noise
      title = "Team Updated";
      body = `Team "${before.name}" has been renamed to "${after.name}"`;
    } else {
      return;
    }

    const tokens = await getOrgTokens(orgId);

    await sendNotification(
      tokens,
      { title, body },
      {
        type: "team_update",
        orgId,
      },
    );
  },
);
