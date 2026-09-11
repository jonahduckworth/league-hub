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

export const invitationResendBatchSize = 100;

export function invitationResendBatches(invitationIds: string[]): string[][] {
  const batches: string[][] = [];
  for (let index = 0; index < invitationIds.length; index += invitationResendBatchSize) {
    batches.push(invitationIds.slice(index, index + invitationResendBatchSize));
  }
  return batches;
}

export function invitationIdSetsMatch(expected: string[], actual: string[]): boolean {
  if (expected.length !== actual.length || new Set(expected).size !== expected.length) {
    return false;
  }
  const actualIds = new Set(actual);
  return actualIds.size === actual.length && expected.every((invitationId) => actualIds.has(invitationId));
}

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

type InvitationCandidate = {
  id: string;
  email?: unknown;
  status?: unknown;
  createdAt?: unknown;
  expiresAt?: unknown;
};

type InvitationUser = {
  email?: unknown;
  isActive?: unknown;
};

function normalizedEmail(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function invitationSortTime(invitation: InvitationCandidate): number {
  return timestampMillis(invitation.createdAt) ?? timestampMillis(invitation.expiresAt) ?? 0;
}

export function resendableExpiredInvitationIds(
  invitations: InvitationCandidate[],
  users: InvitationUser[],
  nowMillis = Date.now(),
): string[] {
  const activeEmails = new Set(users
    .filter((user) => user.isActive === true)
    .map((user) => normalizedEmail(user.email))
    .filter(Boolean));
  const activePendingEmails = new Set(invitations
    .filter((invitation) => invitationIsActivePending(invitation, nowMillis))
    .map((invitation) => normalizedEmail(invitation.email))
    .filter(Boolean));
  const latestByEmail = new Map<string, InvitationCandidate>();

  for (const invitation of invitations) {
    const email = normalizedEmail(invitation.email);
    if (!email || !invitationIsExpired(invitation, nowMillis) ||
        activeEmails.has(email) || activePendingEmails.has(email)) continue;
    const current = latestByEmail.get(email);
    if (!current || invitationSortTime(invitation) > invitationSortTime(current) ||
        (invitationSortTime(invitation) === invitationSortTime(current) && invitation.id > current.id)) {
      latestByEmail.set(email, invitation);
    }
  }

  return [...latestByEmail.values()]
    .sort((first, second) =>
      invitationSortTime(second) - invitationSortTime(first) || first.id.localeCompare(second.id))
    .map((invitation) => invitation.id);
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
