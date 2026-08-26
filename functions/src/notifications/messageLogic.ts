export type MessageNotificationUser = {
  role?: string;
  hubIds?: string[];
  leagueIds?: string[];
  teamIds?: string[];
  blockedUserIds?: string[];
  orgId?: string;
  isActive?: boolean;
};

const elevatedRoles = new Set(["platformOwner", "superAdmin"]);

function hasId(values: unknown, id: string): boolean {
  return Array.isArray(values) && values.includes(id);
}

export function canReceiveMessageNotification(
  user: MessageNotificationUser,
  senderId: string,
  roomType: string,
  hubId?: string,
  leagueId?: string,
  expectedOrgId?: string,
  teamId?: string,
  hubIds: string[] = [],
  teamIds: string[] = [],
): boolean {
  if (user.isActive === false) return false;
  if (expectedOrgId && user.orgId !== expectedOrgId) return false;
  if (hasId(user.blockedUserIds, senderId)) return false;
  if (roomType === "direct") return true;
  if (elevatedRoles.has(user.role ?? "")) return true;
  if (roomType !== "league" && roomType !== "event") return false;
  if (teamIds.length > 0) {
    return teamIds.some((id) => hasId(user.teamIds, id)) ||
      (user.role === "managerAdmin" &&
        hubIds.some((id) => hasId(user.hubIds, id)));
  }
  if (teamId) {
    return hasId(user.teamIds, teamId) ||
      (hubId !== undefined && hasId(user.hubIds, hubId));
  }
  if (hubId) return hasId(user.hubIds, hubId);
  if (leagueId) return hasId(user.leagueIds, leagueId);
  return true;
}

export function participantLookupBatches(
  participantIds: string[],
  maximumBatchSize = 30,
): string[][] {
  const uniqueIds = [...new Set(participantIds.filter((id) => id.length > 0))];
  const batches: string[][] = [];
  for (let index = 0; index < uniqueIds.length; index += maximumBatchSize) {
    batches.push(uniqueIds.slice(index, index + maximumBatchSize));
  }
  return batches;
}

export function shouldUseExplicitParticipantRecipients(
  participantIds: string[],
  teamIds: string[],
): boolean {
  return participantIds.length > 0 && teamIds.length === 0;
}

export function shouldReplaceRoomPreview(
  currentTimeMillis: number | null,
  currentMessageId: string | null,
  incomingTimeMillis: number,
  incomingMessageId: string,
): boolean {
  if (currentTimeMillis === null) return true;
  if (incomingTimeMillis !== currentTimeMillis) {
    return incomingTimeMillis > currentTimeMillis;
  }
  return incomingMessageId.localeCompare(currentMessageId ?? "") > 0;
}
