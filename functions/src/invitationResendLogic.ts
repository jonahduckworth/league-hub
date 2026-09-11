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

export const maximumBulkInvitationResends = 100;

function timestampMillis(value: unknown): number | undefined {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" || typeof value === "string") {
    const parsed = new Date(value).getTime();
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  if (value && typeof value === "object") {
    const timestamp = value as {toMillis?: () => number; toDate?: () => Date};
    if (typeof timestamp.toMillis === "function") return timestamp.toMillis();
    if (typeof timestamp.toDate === "function") return timestamp.toDate().getTime();
  }
  return undefined;
}

export function invitationIsExpired(
  invitation: {status?: unknown; expiresAt?: unknown},
  nowMillis = Date.now(),
): boolean {
  if (invitation.status === "expired") return true;
  const expiresAt = timestampMillis(invitation.expiresAt);
  return invitation.status === "pending" && expiresAt !== undefined && expiresAt <= nowMillis;
}

export function invitationCanBeResent(invitation: {status?: unknown}): boolean {
  return invitation.status === "pending" || invitation.status === "expired";
}

export function invitationIsActivePending(
  invitation: {status?: unknown; expiresAt?: unknown},
  nowMillis = Date.now(),
): boolean {
  const expiresAt = timestampMillis(invitation.expiresAt);
  return invitation.status === "pending" && expiresAt !== undefined && expiresAt > nowMillis;
}

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
