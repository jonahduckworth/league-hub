type AnnouncementAudienceUser = {
  role?: unknown;
  leagueIds?: unknown;
  hubIds?: unknown;
  teamIds?: unknown;
  announcementDelivery?: unknown;
};

type AnnouncementTarget = {
  scope?: unknown;
  leagueId?: unknown;
  hubId?: unknown;
  teamId?: unknown;
};

const elevatedRoles = new Set(["platformOwner", "superAdmin"]);

export type AnnouncementDelivery = "both" | "push" | "email";

export function announcementDeliveryForUser(
  user: AnnouncementAudienceUser,
): AnnouncementDelivery {
  const delivery = user.announcementDelivery;
  return delivery === "push" || delivery === "email" ? delivery : "both";
}

export function shouldSendAnnouncementPush(
  user: AnnouncementAudienceUser,
): boolean {
  return announcementDeliveryForUser(user) !== "email";
}

export function shouldSendAnnouncementEmail(
  user: AnnouncementAudienceUser,
): boolean {
  return announcementDeliveryForUser(user) !== "push";
}

function hasId(values: unknown, id: string): boolean {
  return Array.isArray(values) && values.includes(id);
}

/** Mirrors mobile announcement visibility when selecting channel recipients. */
export function canReceiveAnnouncementNotification(
  user: AnnouncementAudienceUser,
  announcement: AnnouncementTarget,
): boolean {
  const scope = announcement.scope;
  const leagueId = announcement.leagueId;
  const hubId = announcement.hubId;
  const teamId = announcement.teamId;

  if (scope !== "league" && scope !== "hub" && scope !== "team") return false;
  if (typeof leagueId !== "string" || leagueId.length === 0) return false;
  if (elevatedRoles.has(typeof user.role === "string" ? user.role : "")) return true;

  if (scope === "league") return hasId(user.leagueIds, leagueId);
  if (typeof hubId !== "string" || hubId.length === 0) return false;
  if (scope === "hub") return hasId(user.hubIds, hubId);
  if (typeof teamId !== "string" || teamId.length === 0) return false;
  return hasId(user.teamIds, teamId) || hasId(user.hubIds, hubId);
}
