import type { AppUser } from './types';
export type InfoScope = { leagueId: string; hubId: string | null; teamId: string | null };
export type InfoItem = InfoScope & {
  id: string; orgId: string; title: string; status: 'draft' | 'published' | 'archived';
  audience: 'members' | 'management'; sortOrder: number; revision: number;
  canManage: boolean; canReveal: boolean; sectionId?: string; kind?: string;
  url?: string; inviteCode?: string; notes?: string; policyId?: string;
  hasPassword?: boolean; passwordAudience?: 'members' | 'management';
};
export type InfoData = {
  policyOptionsLimited?: boolean;
  structure: {
    leagues: Array<{ id: string; name: string }>;
    hubs: Array<{ id: string; name: string; leagueId: string }>;
    teams: Array<{ id: string; name: string; leagueId: string; hubId: string }>;
  };
  sections: InfoItem[]; entries: InfoItem[]; policies: Array<{ id: string; name: string }>;
};
export function canManageInfoScope(user: AppUser, scope: InfoScope): boolean {
  if (!user.isActive) return false;
  if (user.role === 'platformOwner' || user.role === 'superAdmin') return true;
  if (user.role !== 'managerAdmin') return false;
  return scope.teamId ? user.teamIds.includes(scope.teamId) || user.hubIds.includes(scope.hubId ?? '')
    : Boolean(scope.hubId && user.hubIds.includes(scope.hubId));
}
export function infoScopeLabel(item: InfoScope, data: InfoData): string {
  return data.structure.teams.find((x) => x.id === item.teamId)?.name
    ?? data.structure.hubs.find((x) => x.id === item.hubId)?.name
    ?? data.structure.leagues.find((x) => x.id === item.leagueId)?.name ?? 'Unavailable scope';
}
export function infoItemInHub(item: InfoScope, hubId: string, data: InfoData): boolean {
  if (!hubId) return true;
  const hub = data.structure.hubs.find((x) => x.id === hubId);
  return Boolean(hub && item.leagueId === hub.leagueId && (!item.hubId || item.hubId === hubId));
}
