export type AccountDeletionProfile = {
  id?: unknown;
  orgId?: unknown;
  role?: unknown;
  avatarUrl?: unknown;
};

export function hasRecentAuthentication(
  authenticatedAt: unknown,
  nowSeconds: number,
  maximumAgeSeconds = 5 * 60,
): boolean {
  return typeof authenticatedAt === "number" &&
    Number.isFinite(authenticatedAt) &&
    authenticatedAt <= nowSeconds &&
    nowSeconds - authenticatedAt <= maximumAgeSeconds;
}

export function accountDeletionBlockedByOwnership(
  authenticatedUserId: string,
  profile: AccountDeletionProfile,
  organizationOwnerId: unknown,
): boolean {
  return profile.role === "platformOwner" ||
    organizationOwnerId === authenticatedUserId;
}

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

export function isMissingAuthUserError(error: unknown): boolean {
  return typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as {code?: unknown}).code === "auth/user-not-found";
}
