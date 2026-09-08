export type InvitationReplacementInput = {
  orgId: string;
  email: string;
  displayName?: string | null;
  title?: string | null;
  role: string;
  leagueIds: string[];
  hubIds: string[];
  teamIds: string[];
  invitedBy: string;
  invitedByName: string;
  createdAt: unknown;
  expiresAt: unknown;
  token: string;
  replacesInvitationId: string;
};

export function invitationReplacementData(input: InvitationReplacementInput) {
  return {
    orgId: input.orgId,
    email: input.email,
    displayName: input.displayName ?? null,
    title: input.title ?? null,
    role: input.role,
    leagueIds: input.leagueIds,
    hubIds: input.hubIds,
    teamIds: input.teamIds,
    invitedBy: input.invitedBy,
    invitedByName: input.invitedByName,
    createdAt: input.createdAt,
    expiresAt: input.expiresAt,
    status: "pending",
    token: input.token,
    emailDeliveryStatus: "pending",
    suppressAdminNotification: true,
    replacesInvitationId: input.replacesInvitationId,
  };
}
