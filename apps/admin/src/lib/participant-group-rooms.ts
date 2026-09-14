import type { AppUser, ChatRoom } from "./types";

export const MAX_PARTICIPANT_GROUP_MEMBERS = 50;
export const MIN_PARTICIPANT_GROUP_MEMBERS = 2;

export type ParticipantGroupMemberOption = {
  id: string;
  displayName: string;
  email?: string;
  title?: string | null;
  role: AppUser["role"] | null;
  isEligible: boolean;
  isKnown: boolean;
  isActive: boolean;
};

export function isParticipantGroupRoom(room: ChatRoom | null): boolean {
  return Boolean(
    room &&
    !room.isArchived &&
    room.type === "event" &&
    room.roomPurpose === "group" &&
    room.accessMode === "participants"
  );
}

export function participantGroupMemberOptions(
  users: AppUser[],
  orgId: string,
  existingParticipantIds: Iterable<string>
): ParticipantGroupMemberOption[] {
  const existingIds = new Set(existingParticipantIds);
  const usersById = new Map(users.map((user) => [user.id, user]));
  const ids = new Set([
    ...existingIds,
    ...users
      .filter((user) => user.orgId === orgId && user.isActive)
      .map((user) => user.id)
  ]);

  return [...ids]
    .map((id) => {
      const user = usersById.get(id);
      if (!user) {
        return {
          id,
          displayName: "Unknown member",
          role: null,
          isEligible: false,
          isKnown: false,
          isActive: false
        };
      }
      const isEligible = user.orgId === orgId && user.isActive;
      return {
        id,
        displayName: user.displayName || user.email || "Unnamed member",
        email: user.email,
        title: user.title,
        role: user.role,
        isEligible,
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

export function participantIdsChanged(left: string[], right: Iterable<string>): boolean {
  const leftSet = new Set(left);
  const rightSet = new Set(right);
  return leftSet.size !== rightSet.size || [...leftSet].some((id) => !rightSet.has(id));
}
