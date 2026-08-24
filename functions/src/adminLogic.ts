import { createHash } from "crypto";

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

export type ChatRoomSetupScope = "hub" | "team";

export type ChatRoomSetupHub = {
  id: string;
  leagueId: string;
  name: string;
  logoUrl?: string | null;
  iconName?: string | null;
};

export type ChatRoomSetupTeam = ChatRoomSetupHub & {
  hubId: string;
};

export type ChatRoomSetupRoom = {
  id: string;
  name?: unknown;
  type?: unknown;
  leagueId?: unknown;
  hubId?: unknown;
  teamId?: unknown;
  isArchived?: unknown;
  roomIconName?: unknown;
  roomImageUrl?: unknown;
};

export type ChatRoomSetupTarget = {
  key: string;
  scope: ChatRoomSetupScope;
  name: string;
  leagueId: string;
  hubId: string;
  teamId: string | null;
  roomIconName: string | null;
  roomImageUrl: string | null;
  action: "create" | "restore" | "sync";
  existingRoomId: string | null;
};

export type ChatRoomSetupPlan = {
  totalHubs: number;
  totalTeams: number;
  coveredHubs: number;
  coveredTeams: number;
  createCount: number;
  restoreCount: number;
  syncCount: number;
  targets: ChatRoomSetupTarget[];
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
  return value === "Policy" || value === "Waiver" || value === "Protocol" || value === "Code of Conduct" || value === "Other";
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

export function chatRoomSetupTargetKey(
  scope: ChatRoomSetupScope,
  leagueId: string,
  hubId: string,
  teamId?: string | null,
): string {
  return scope === "team"
    ? `team:${leagueId}:${hubId}:${teamId ?? ""}`
    : `hub:${leagueId}:${hubId}`;
}

function roomMatchesSetupTarget(
  room: ChatRoomSetupRoom,
  scope: ChatRoomSetupScope,
  leagueId: string,
  hubId: string,
  teamId?: string | null,
): boolean {
  // Event rooms can share a hub/team scope, but they are not the canonical
  // General room derived from Structure.
  if (room.type !== "league") return false;
  if (room.leagueId !== leagueId || room.hubId !== hubId) return false;
  return scope === "team"
    ? room.teamId === teamId
    : room.teamId == null;
}

export function buildChatRoomSetupPlan({
  hubs,
  teams,
  rooms,
}: {
  hubs: ChatRoomSetupHub[];
  teams: ChatRoomSetupTeam[];
  rooms: ChatRoomSetupRoom[];
}): ChatRoomSetupPlan {
  const sortedRooms = [...rooms].sort((left, right) => left.id.localeCompare(right.id));
  const targets: ChatRoomSetupTarget[] = [];
  let coveredHubs = 0;
  let coveredTeams = 0;

  const addTarget = ({
    scope,
    id,
    name,
    leagueId,
    hubId,
    logoUrl,
    iconName,
  }: {
    scope: ChatRoomSetupScope;
    id: string;
    name: string;
    leagueId: string;
    hubId: string;
    logoUrl?: string | null;
    iconName?: string | null;
  }) => {
    const teamId = scope === "team" ? id : null;
    const matchingRooms = sortedRooms.filter((room) => (
      roomMatchesSetupTarget(room, scope, leagueId, hubId, teamId)
    ));
    const expectedName = `${name} - General`;
    const expectedIconName = iconName ?? scope;
    const expectedImageUrl = logoUrl ?? null;
    const activeRoom = matchingRooms.find((room) => room.isArchived !== true);
    if (activeRoom) {
      if (scope === "hub") coveredHubs += 1;
      else coveredTeams += 1;
      const needsSync = activeRoom.name !== expectedName ||
        (activeRoom.roomImageUrl ?? null) !== expectedImageUrl ||
        (!expectedImageUrl && (activeRoom.roomIconName ?? null) !== expectedIconName);
      if (needsSync) {
        targets.push({
          key: chatRoomSetupTargetKey(scope, leagueId, hubId, teamId),
          scope,
          name: expectedName,
          leagueId,
          hubId,
          teamId,
          roomIconName: expectedIconName,
          roomImageUrl: expectedImageUrl,
          action: "sync",
          existingRoomId: activeRoom.id,
        });
      }
      return;
    }
    const archivedRoom = matchingRooms.find((room) => room.isArchived === true);
    targets.push({
      key: chatRoomSetupTargetKey(scope, leagueId, hubId, teamId),
      scope,
      name: expectedName,
      leagueId,
      hubId,
      teamId,
      roomIconName: expectedIconName,
      roomImageUrl: expectedImageUrl,
      action: archivedRoom ? "restore" : "create",
      existingRoomId: archivedRoom?.id ?? null,
    });
  };

  for (const hub of [...hubs].sort((left, right) => left.name.localeCompare(right.name))) {
    addTarget({
      scope: "hub",
      id: hub.id,
      name: hub.name,
      leagueId: hub.leagueId,
      hubId: hub.id,
      logoUrl: hub.logoUrl,
      iconName: hub.iconName,
    });
  }
  for (const team of [...teams].sort((left, right) => left.name.localeCompare(right.name))) {
    addTarget({
      scope: "team",
      id: team.id,
      name: team.name,
      leagueId: team.leagueId,
      hubId: team.hubId,
      logoUrl: team.logoUrl,
      iconName: team.iconName,
    });
  }

  return {
    totalHubs: hubs.length,
    totalTeams: teams.length,
    coveredHubs,
    coveredTeams,
    createCount: targets.filter((target) => target.action === "create").length,
    restoreCount: targets.filter((target) => target.action === "restore").length,
    syncCount: targets.filter((target) => target.action === "sync").length,
    targets,
  };
}

export function chatRoomSetupPreviewToken(plan: ChatRoomSetupPlan): string {
  const serialized = JSON.stringify({
    totalHubs: plan.totalHubs,
    totalTeams: plan.totalTeams,
    coveredHubs: plan.coveredHubs,
    coveredTeams: plan.coveredTeams,
    createCount: plan.createCount,
    restoreCount: plan.restoreCount,
    targets: [...plan.targets]
      .sort((left, right) => left.key.localeCompare(right.key))
      .map((target) => ({
        key: target.key,
        scope: target.scope,
        name: target.name,
        action: target.action,
        existingRoomId: target.existingRoomId,
        roomIconName: target.roomIconName,
        roomImageUrl: target.roomImageUrl,
      })),
  });
  return createHash("sha256").update(serialized).digest("hex");
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
