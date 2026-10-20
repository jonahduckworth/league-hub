export type InfoActor = {
  id: string; role: string; orgId?: string; isActive?: boolean;
  leagueIds?: string[]; hubIds?: string[]; teamIds?: string[];
};
export type InfoScope = {leagueId: string; hubId: string | null; teamId: string | null};
export type InfoRecord = InfoScope & {
  id: string; orgId: string; title: string; sectionId?: string; kind?: string;
  status: string; audience: string; passwordAudience?: string; revision: number;
  [key: string]: unknown;
};
export type InfoStructure = {
  leagues: Array<{id: string; name: string}>;
  hubs: Array<{id: string; name: string; leagueId: string}>;
  teams: Array<{id: string; name: string; leagueId: string; hubId: string}>;
};
export const elevated = (user: InfoActor): boolean =>
  user.role === "platformOwner" || user.role === "superAdmin";
export const sameOrganization = (user: InfoActor, orgId: string): boolean =>
  user.isActive === true && ["platformOwner", "superAdmin", "managerAdmin", "staff"].includes(user.role) &&
  (user.role === "platformOwner" || user.orgId === orgId);
export function canManageInfo(user: InfoActor, scope: InfoScope): boolean {
  if (!user.isActive) return false;
  if (elevated(user)) return true;
  if (user.role !== "managerAdmin") return false;
  if (scope.teamId) return Boolean(user.teamIds?.includes(scope.teamId) || user.hubIds?.includes(scope.hubId || ""));
  return Boolean(scope.hubId && user.hubIds?.includes(scope.hubId));
}
export function readableScope(user: InfoActor, scope: InfoScope, structure: InfoStructure): boolean {
  if (elevated(user)) return true;
  if (scope.teamId) return Boolean(user.teamIds?.includes(scope.teamId) ||
    (user.role === "managerAdmin" && user.hubIds?.includes(scope.hubId || "")));
  const assignedTeams = structure.teams.filter((team) => user.teamIds?.includes(team.id));
  const hubIds = new Set([...(user.hubIds || []), ...assignedTeams.map((team) => team.hubId)]);
  if (scope.hubId) return hubIds.has(scope.hubId);
  return Boolean(user.leagueIds?.includes(scope.leagueId) ||
    structure.hubs.some((hub) => hub.leagueId === scope.leagueId && hubIds.has(hub.id)));
}
export function canReadInfo(user: InfoActor, item: InfoRecord, structure: InfoStructure, preview = false): boolean {
  if (!sameOrganization(user, item.orgId) || item.status === "archived") return false;
  if (preview && item.status !== "published") return false;
  if (item.status !== "published" && !canManageInfo(user, item)) return false;
  if (item.audience === "management" && user.role === "staff") return false;
  return readableScope(user, item, structure);
}
export function canRevealInfo(user: InfoActor, item: InfoRecord, structure: InfoStructure): boolean {
  return canReadInfo(user, item, structure) &&
    (item.passwordAudience === "members" || user.role !== "staff");
}
export function containsScope(parent: InfoScope, child: InfoScope): boolean {
  return parent.leagueId === child.leagueId &&
    (!parent.hubId || parent.hubId === child.hubId) &&
    (!parent.teamId || parent.teamId === child.teamId);
}
export function validateScope(scope: InfoScope, structure: InfoStructure): boolean {
  return structure.leagues.some((league) => league.id === scope.leagueId) &&
    (!scope.teamId || Boolean(scope.hubId)) &&
    (!scope.hubId || structure.hubs.some((hub) => hub.id === scope.hubId && hub.leagueId === scope.leagueId)) &&
    (!scope.teamId || structure.teams.some((team) => team.id === scope.teamId && team.hubId === scope.hubId && team.leagueId === scope.leagueId));
}
