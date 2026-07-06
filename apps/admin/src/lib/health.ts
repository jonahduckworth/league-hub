import type { AdminData, HealthCheck } from "./types";

export function buildHealthChecks(data: AdminData): HealthCheck[] {
  const teamIds = new Set(data.teams.map((team) => team.id));
  const hubIds = new Set(data.hubs.map((hub) => hub.id));
  const orphanedTeamAssignments = data.users.reduce((count, user) => {
    return count + user.teamIds.filter((id) => !teamIds.has(id)).length;
  }, 0);
  const orphanedHubAssignments = data.users.reduce((count, user) => {
    return count + user.hubIds.filter((id) => !hubIds.has(id)).length;
  }, 0);
  const missingTeamLogos = data.teams.filter((team) => !team.logoUrl && !team.iconName).length;
  const notificationFailures = data.notificationEvents.reduce((count, event) => {
    return count + event.failureCount;
  }, 0);

  return [
    {
      id: "assignments",
      label: "Assignments",
      severity: orphanedTeamAssignments + orphanedHubAssignments > 0 ? "danger" : "good",
      value: `${orphanedTeamAssignments + orphanedHubAssignments} broken`
    },
    {
      id: "logos",
      label: "Team Identity",
      severity: missingTeamLogos > 0 ? "warning" : "good",
      value: `${missingTeamLogos} missing`
    },
    {
      id: "notifications",
      label: "Notifications",
      severity: notificationFailures > 0 ? "warning" : "good",
      value: `${notificationFailures} failed`
    },
    {
      id: "invites",
      label: "Invitations",
      severity: data.invitations.some((invite) => invite.status === "pending") ? "warning" : "good",
      value: `${data.invitations.filter((invite) => invite.status === "pending").length} pending`
    }
  ];
}
