export type UserRole = "platformOwner" | "superAdmin" | "managerAdmin" | "staff";

export type ActorLike = {
  id: string;
  orgId?: string | null;
  role?: string | null;
  isActive?: boolean | null;
};

export type TargetLike = {
  id: string;
  orgId?: string | null;
  role?: string | null;
};

const roleOrder: UserRole[] = [
  "platformOwner",
  "superAdmin",
  "managerAdmin",
  "staff",
];

export function isUserRole(role: unknown): role is UserRole {
  return typeof role === "string" && roleOrder.includes(role as UserRole);
}

export function isAdminRole(role: unknown): role is "platformOwner" | "superAdmin" {
  return role === "platformOwner" || role === "superAdmin";
}

export function canAccessOrg(actor: ActorLike, orgId: string): boolean {
  if (!actor.isActive || !isAdminRole(actor.role)) return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId === orgId;
}

export function canCreateLeague(actor: ActorLike): boolean {
  return actor.isActive === true && actor.role === "platformOwner";
}

export function isValidAnnouncementTarget(value: Record<string, unknown>): boolean {
  const scope = value.scope;
  const leagueId = value.leagueId;
  const hubId = value.hubId;
  const teamId = value.teamId;
  if (scope !== "league" && scope !== "hub" && scope !== "team") return false;
  if (typeof leagueId !== "string" || leagueId.trim().length === 0) return false;
  if (scope === "league") return hubId == null && teamId == null;
  if (typeof hubId !== "string" || hubId.trim().length === 0) return false;
  if (scope === "hub") return teamId == null;
  return typeof teamId === "string" && teamId.trim().length > 0;
}

export function isValidPolicyCategory(value: unknown): boolean {
  return value === "Policy" || value === "Protocol" || value === "Code of Conduct" || value === "Other";
}

export function isOrganizationWidePolicyTarget(value: Record<string, unknown>): boolean {
  return value.leagueId == null && value.hubId == null && value.teamId == null;
}

export function initialPolicyUploadMode(fileUrl: unknown): "ready" | "uploading" {
  return typeof fileUrl === "string" && fileUrl.trim().length > 0
    ? "ready"
    : "uploading";
}

export function outranks(actorRole: unknown, targetRole: unknown): boolean {
  if (!isUserRole(actorRole) || !isUserRole(targetRole)) return false;
  return roleOrder.indexOf(actorRole) < roleOrder.indexOf(targetRole);
}

export function assignableRoles(actorRole: unknown): UserRole[] {
  if (actorRole === "platformOwner") {
    return ["superAdmin", "managerAdmin", "staff"];
  }
  if (actorRole === "superAdmin") {
    return ["managerAdmin", "staff"];
  }
  return [];
}

export function canManageInvitationRole(
  actorRole: unknown,
  invitationRole: unknown,
): boolean {
  return isUserRole(invitationRole) &&
    assignableRoles(actorRole).includes(invitationRole);
}

export function isManagedChatRoomType(value: unknown): boolean {
  return value === "league" || value === "event";
}

export function teamMemberRecordsMatchOrg(
  memberIds: string[],
  orgId: string,
  records: Array<{ id: string; orgId?: unknown }>,
): boolean {
  const orgByUserId = new Map(records.map((record) => [record.id, record.orgId]));
  return memberIds.every((memberId) => orgByUserId.get(memberId) === orgId);
}

export function canManageTarget(actor: ActorLike, target: TargetLike): boolean {
  if (!actor.isActive || !isAdminRole(actor.role)) return false;
  if (actor.id === target.id) return false;
  if (target.role === "platformOwner") return false;
  if (!outranks(actor.role, target.role)) return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId != null && actor.orgId === target.orgId;
}

export function canManageTargetAssignments(
  actor: ActorLike,
  target: TargetLike,
): boolean {
  if (!actor.isActive || !isAdminRole(actor.role)) return false;
  if (actor.id === target.id) return false;
  if (target.role === "platformOwner") return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId != null &&
    actor.orgId === target.orgId &&
    isUserRole(target.role);
}

export function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((item): item is string => {
    return typeof item === "string" && item.trim().length > 0;
  }).map((item) => item.trim()))];
}

export function nullableStringPatch(
  source: Record<string, unknown>,
  fields: string[],
  existing: boolean,
): Record<string, string | null> {
  const patch: Record<string, string | null> = {};
  for (const field of fields) {
    if (existing && !(field in source)) continue;
    const value = source[field];
    patch[field] = typeof value === "string" && value.trim().length > 0
      ? value.trim()
      : null;
  }
  return patch;
}
