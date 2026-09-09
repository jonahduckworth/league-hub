export const maximumMultiTeamEventRoomTeams = 50;
export const multiTeamLegacyScopeSentinel = "__multi_team__";

export type MultiTeamTarget = {
  hubId: string;
  teamId: string;
};

export type MultiTeamActor = {
  role?: string;
  orgId?: string;
  isActive?: boolean;
  hubIds?: unknown;
  teamIds?: unknown;
};

export type MultiTeamAudienceUser = MultiTeamActor & {
  id: string;
  orgId?: string;
  isActive?: boolean;
};

export type ExistingEventRoomAudience = {
  teamIds: string[];
  scopeKey: string;
  legacy: boolean;
};

function hasId(values: unknown, id: string): boolean {
  return Array.isArray(values) && values.includes(id);
}

export function canCreateMultiTeamEventRoom(
  actor: MultiTeamActor,
  targets: MultiTeamTarget[],
): boolean {
  if (actor.role === "platformOwner" || actor.role === "superAdmin") return true;
  if (actor.role !== "managerAdmin") return false;
  return targets.every((target) => hasId(actor.teamIds, target.teamId)) ||
    targets.every((target) => hasId(actor.hubIds, target.hubId));
}

export function canEditMultiTeamEventRoomAudience(
  actor: MultiTeamActor,
  orgId: string,
): boolean {
  if (actor.isActive !== true) return false;
  if (actor.role === "platformOwner") return true;
  return actor.role === "superAdmin" && actor.orgId === orgId;
}

export function sameMultiTeamAudience(
  left: string[],
  right: string[],
): boolean {
  if (left.length !== right.length) return false;
  const leftIds = new Set(left);
  return leftIds.size === right.length && right.every((id) => leftIds.has(id));
}

function storedId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= 200 ? trimmed : null;
}

/**
 * Normalizes both current multi-team rooms and legacy singular-scope rooms.
 * A null result means the stored scope is malformed and must fail closed.
 */
export function existingEventRoomAudience(
  room: {teamIds?: unknown; teamId?: unknown; hubId?: unknown},
): ExistingEventRoomAudience | null {
  if (room.teamIds != null) {
    if (!Array.isArray(room.teamIds) ||
        room.teamIds.length > maximumMultiTeamEventRoomTeams) return null;
    const teamIds = room.teamIds.map(storedId);
    if (teamIds.some((id) => id == null)) return null;
    const normalizedTeamIds = teamIds as string[];
    if (new Set(normalizedTeamIds).size !== normalizedTeamIds.length) return null;
    if (normalizedTeamIds.length > 0) {
      return {teamIds: normalizedTeamIds, scopeKey: "multi", legacy: false};
    }
  }

  const teamId = storedId(room.teamId);
  if (teamId === multiTeamLegacyScopeSentinel) return null;
  if (teamId) {
    return {teamIds: [teamId], scopeKey: `team:${teamId}`, legacy: true};
  }

  const hubId = storedId(room.hubId);
  if (hubId === multiTeamLegacyScopeSentinel) return null;
  if (hubId) {
    return {teamIds: [], scopeKey: `hub:${hubId}`, legacy: true};
  }

  return {teamIds: [], scopeKey: "league", legacy: true};
}

export function belongsToMultiTeamEventRoomAudience(
  user: MultiTeamAudienceUser,
  orgId: string,
  targets: MultiTeamTarget[],
): boolean {
  if (user.isActive !== true || user.orgId !== orgId) return false;
  if (targets.some((target) => hasId(user.teamIds, target.teamId))) return true;
  return user.role === "managerAdmin" &&
    targets.some((target) => hasId(user.hubIds, target.hubId));
}
