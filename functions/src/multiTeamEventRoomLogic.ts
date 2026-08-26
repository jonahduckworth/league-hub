export const maximumMultiTeamEventRoomTeams = 50;
export const multiTeamLegacyScopeSentinel = "__multi_team__";

export type MultiTeamTarget = {
  hubId: string;
  teamId: string;
};

export type MultiTeamActor = {
  role?: string;
  hubIds?: unknown;
  teamIds?: unknown;
};

export type MultiTeamAudienceUser = MultiTeamActor & {
  id: string;
  orgId?: string;
  isActive?: boolean;
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
