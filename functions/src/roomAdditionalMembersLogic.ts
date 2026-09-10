export const maximumAdditionalRoomMembers = 50;

type RoomLike = {
  type?: unknown;
  roomPurpose?: unknown;
  teamId?: unknown;
  isArchived?: unknown;
  additionalMemberIds?: unknown;
};

type UserLike = {
  role?: unknown;
  orgId?: unknown;
  isActive?: unknown;
  hubIds?: unknown;
  teamIds?: unknown;
};

function storedId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= 200 ? trimmed : null;
}

export function existingAdditionalMemberIds(room: RoomLike): string[] | null {
  if (room.additionalMemberIds == null) return [];
  if (!Array.isArray(room.additionalMemberIds) ||
      room.additionalMemberIds.length > maximumAdditionalRoomMembers) return null;
  const ids = room.additionalMemberIds.map(storedId);
  if (ids.some((id) => id == null)) return null;
  const normalized = ids as string[];
  if (new Set(normalized).size !== normalized.length) return null;
  return normalized;
}

export function sameAdditionalMemberIds(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  const leftIds = new Set(left);
  return leftIds.size === right.length && right.every((id) => leftIds.has(id));
}

export function isRoomEligibleForAdditionalMembers(room: RoomLike): boolean {
  if (room.isArchived === true) return false;
  if (room.type === "event") {
    return room.roomPurpose == null || room.roomPurpose === "event";
  }
  return room.type === "league" && storedId(room.teamId) !== null;
}

function hasNoAssignments(value: unknown): boolean {
  return value == null || (Array.isArray(value) && value.length === 0);
}

export function isAdditionalRoomMemberCandidate(
  user: UserLike,
  orgId: string,
): boolean {
  if (user.isActive !== true || user.orgId !== orgId) return false;
  if (user.role === "platformOwner" || user.role === "superAdmin") return false;
  return hasNoAssignments(user.hubIds) && hasNoAssignments(user.teamIds);
}
