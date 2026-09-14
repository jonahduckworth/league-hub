export const maximumParticipantGroupMembers = 50;
export const minimumParticipantGroupMembers = 2;
export const participantGroupScopeSentinel = "__participant_group__";

export type ParticipantGroupActor = {
  id?: string;
  orgId?: string | null;
  role?: string | null;
  isActive?: boolean | null;
};

export type ParticipantGroupUser = {
  id: string;
  orgId?: string | null;
  isActive?: boolean | null;
};

export type ParticipantGroupRoom = {
  orgId?: unknown;
  type?: unknown;
  roomPurpose?: unknown;
  accessMode?: unknown;
  leagueId?: unknown;
  hubId?: unknown;
  teamId?: unknown;
  hubIds?: unknown;
  teamIds?: unknown;
  additionalMemberIds?: unknown;
  participants?: unknown;
  isArchived?: unknown;
};

export function canManageParticipantGroups(
  actor: ParticipantGroupActor,
  orgId: string,
): boolean {
  if (actor.isActive !== true) return false;
  if (actor.role === "platformOwner") return true;
  return actor.role === "superAdmin" && actor.orgId === orgId;
}

export function usesParticipantGroupAccess(room: ParticipantGroupRoom): boolean {
  return room.type === "event" &&
    room.roomPurpose === "group" &&
    room.accessMode === "participants";
}

export function isParticipantGroupRoom(room: ParticipantGroupRoom): boolean {
  return usesParticipantGroupAccess(room) &&
    room.isArchived !== true &&
    room.leagueId == null &&
    room.hubId === participantGroupScopeSentinel &&
    room.teamId === participantGroupScopeSentinel &&
    Array.isArray(room.hubIds) && room.hubIds.length === 0 &&
    Array.isArray(room.teamIds) && room.teamIds.length === 0 &&
    Array.isArray(room.additionalMemberIds) &&
    room.additionalMemberIds.length === 0 &&
    Array.isArray(room.participants);
}

export function sameParticipantIds(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  const leftSet = new Set(left);
  const rightSet = new Set(right);
  return leftSet.size === left.length &&
    rightSet.size === right.length &&
    leftSet.size === rightSet.size &&
    [...leftSet].every((id) => rightSet.has(id));
}

export function participantRecordsMatchOrganization(
  participantIds: string[],
  orgId: string,
  records: ParticipantGroupUser[],
): boolean {
  if (participantIds.length < minimumParticipantGroupMembers ||
      participantIds.length > maximumParticipantGroupMembers ||
      new Set(participantIds).size !== participantIds.length) {
    return false;
  }
  const recordsById = new Map(records.map((record) => [record.id, record]));
  return participantIds.every((id) => {
    const record = recordsById.get(id);
    return record?.orgId === orgId && record.isActive === true;
  });
}
