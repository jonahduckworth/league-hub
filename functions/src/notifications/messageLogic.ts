export type MessageNotificationUser = {
  role?: string;
  hubIds?: string[];
  leagueIds?: string[];
  teamIds?: string[];
  blockedUserIds?: string[];
  orgId?: string;
  isActive?: boolean;
  fcmTokens?: unknown;
  appBadgeEnabled?: unknown;
};

export type ChatNotificationDeliveryGroup = {
  tokens: string[];
  badge?: number;
};

export type RoomPreviewContent = {
  lastMessage: string;
  lastMessageBy: string | null;
  lastMessageSenderId: string | null;
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
  additionalMemberIds: string[] = [],
  userId?: string,
  accessMode?: string,
): boolean {
  if (user.isActive === false) return false;
  if (expectedOrgId && user.orgId !== expectedOrgId) return false;
  if (hasId(user.blockedUserIds, senderId)) return false;
  if (roomType === "direct") return true;
  // The caller resolves participant-only rooms from their exact participant
  // list, so assignment-based filtering must not remove selected Staff or
  // Managers from notification delivery.
  if (accessMode === "participants") return true;
  if (elevatedRoles.has(user.role ?? "")) return true;
  if (roomType !== "league" && roomType !== "event") return false;
  if (userId && additionalMemberIds.includes(userId)) return true;
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
  accessMode?: string,
): boolean {
  if (accessMode === "participants") return true;
  return participantIds.length > 0 && teamIds.length === 0;
}

export function notificationLookupIds(
  participantIds: string[],
  additionalMemberIds: string[],
  roomType: string,
  accessMode?: string,
): string[] {
  if (accessMode === "participants") return [...new Set(participantIds)];
  if (roomType !== "league" && roomType !== "event") return participantIds;
  return [...new Set([...participantIds, ...additionalMemberIds])];
}

/**
 * A chat push uses a binary iOS attention badge. The badge is cleared when the
 * app is opened or resumed; it intentionally does not claim to be an exact
 * unread-message counter.
 */
export function chatNotificationDeliveryGroups(
  recipients: MessageNotificationUser[],
): ChatNotificationDeliveryGroup[] {
  const badgeTokens: string[] = [];
  const noBadgeTokens: string[] = [];
  for (const recipient of recipients) {
    const tokens = Array.isArray(recipient.fcmTokens) ?
      recipient.fcmTokens.filter((token): token is string =>
        typeof token === "string" && token.length > 0) : [];
    if (recipient.appBadgeEnabled === false) {
      noBadgeTokens.push(...tokens);
    } else {
      badgeTokens.push(...tokens);
    }
  }
  return [
    {tokens: badgeTokens, badge: 1},
    {tokens: noBadgeTokens},
  ];
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

/**
 * Room documents are readable by administrators for management. Participant-
 * only rooms therefore store a generic activity preview so an unselected
 * administrator cannot infer private message content or the sender.
 */
export function visibleRoomPreview(
  accessMode: unknown,
  senderName: string,
  senderId: string,
  previewText: string,
): RoomPreviewContent {
  if (accessMode === "participants") {
    return {
      lastMessage: "New message",
      lastMessageBy: null,
      lastMessageSenderId: null,
    };
  }
  return {
    lastMessage: previewText,
    lastMessageBy: senderName,
    lastMessageSenderId: senderId,
  };
}
