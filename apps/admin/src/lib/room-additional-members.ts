import type { AppUser, ChatRoom } from "./types";

export const MAX_ADDITIONAL_ROOM_MEMBERS = 50;

export type AdditionalRoomMemberOption = {
  id: string;
  displayName: string;
  email?: string;
  title?: string | null;
  isEligible: boolean;
  isKnown: boolean;
  isActive: boolean;
};

export function canEditAdditionalRoomMembers(user: AppUser): boolean {
  return user.isActive && (user.role === "platformOwner" || user.role === "superAdmin");
}

export function roomSupportsAdditionalMembers(room: ChatRoom | null): boolean {
  if (!room || room.isArchived) return false;
  if (room.type === "event") {
    return room.roomPurpose == null || room.roomPurpose === "event";
  }
  return room.type === "league" && Boolean(room.teamId?.trim());
}

export function isAdditionalRoomMemberCandidate(user: AppUser, orgId: string): boolean {
  return user.isActive &&
    user.orgId === orgId &&
    user.role !== "platformOwner" &&
    user.role !== "superAdmin" &&
    (user.hubIds?.length ?? 0) === 0 &&
    (user.teamIds?.length ?? 0) === 0;
}

export function additionalRoomMemberOptions(
  users: AppUser[],
  orgId: string,
  existingMemberIds: Iterable<string>
): AdditionalRoomMemberOption[] {
  const existingIds = new Set(existingMemberIds);
  const usersById = new Map(users.map((user) => [user.id, user]));
  const ids = new Set([
    ...existingIds,
    ...users.filter((user) => isAdditionalRoomMemberCandidate(user, orgId)).map((user) => user.id)
  ]);

  return [...ids]
    .map((id) => {
      const user = usersById.get(id);
      if (!user) {
        return {
          id,
          displayName: "Unknown member",
          isEligible: false,
          isKnown: false,
          isActive: false
        };
      }
      return {
        id,
        displayName: user.displayName || user.email || "Unnamed member",
        email: user.email,
        title: user.title,
        isEligible: isAdditionalRoomMemberCandidate(user, orgId),
        isKnown: true,
        isActive: user.isActive
      };
    })
    .sort((left, right) =>
      left.displayName.localeCompare(right.displayName) ||
      (left.email ?? "").localeCompare(right.email ?? "") ||
      left.id.localeCompare(right.id)
    );
}
