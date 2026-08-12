export type AccountDeletionProfile = {
  id?: unknown;
  orgId?: unknown;
  avatarUrl?: unknown;
};

export function accountDeletionUserMatches(
  authenticatedUserId: string,
  profile: AccountDeletionProfile | undefined,
): boolean {
  return profile !== undefined && profile.id === authenticatedUserId;
}

export function accountAvatarPath(
  authenticatedUserId: string,
  profile: AccountDeletionProfile,
): string | null {
  if (typeof profile.orgId !== "string" || profile.orgId.length === 0) return null;
  if (typeof profile.avatarUrl !== "string" || profile.avatarUrl.length === 0) return null;
  return `orgs/${profile.orgId}/avatars/${authenticatedUserId}.jpg`;
}
