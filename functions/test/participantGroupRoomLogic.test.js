const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canManageParticipantGroups,
  isParticipantGroupRoom,
  participantRecordsMatchOrganization,
  sameParticipantIds,
  usesParticipantGroupAccess,
} = require("../lib/participantGroupRoomLogic");

test("only active Platform Owners and same-organization Admins manage Group Chats", () => {
  assert.equal(canManageParticipantGroups({role: "platformOwner", isActive: true}, "org-1"), true);
  assert.equal(canManageParticipantGroups({role: "superAdmin", orgId: "org-1", isActive: true}, "org-1"), true);
  assert.equal(canManageParticipantGroups({role: "superAdmin", orgId: "org-2", isActive: true}, "org-1"), false);
  assert.equal(canManageParticipantGroups({role: "managerAdmin", orgId: "org-1", isActive: true}, "org-1"), false);
  assert.equal(canManageParticipantGroups({role: "staff", orgId: "org-1", isActive: true}, "org-1"), false);
  assert.equal(canManageParticipantGroups({role: "superAdmin", orgId: "org-1", isActive: false}, "org-1"), false);
});

test("participant-only Group Chats require the complete room contract", () => {
  const room = {
    type: "event",
    roomPurpose: "group",
    accessMode: "participants",
    leagueId: null,
    hubId: "__participant_group__",
    teamId: "__participant_group__",
    hubIds: [],
    teamIds: [],
    additionalMemberIds: [],
    participants: ["admin", "staff"],
    isArchived: false,
  };
  assert.equal(isParticipantGroupRoom(room), true);
  assert.equal(usesParticipantGroupAccess(room), true);
  assert.equal(isParticipantGroupRoom({...room, accessMode: "scope"}), false);
  assert.equal(isParticipantGroupRoom({...room, roomPurpose: "event"}), false);
  assert.equal(isParticipantGroupRoom({...room, isArchived: true}), false);
  assert.equal(isParticipantGroupRoom({...room, hubId: "hub-1"}), false);
  assert.equal(isParticipantGroupRoom({...room, teamIds: ["team-1"]}), false);
  assert.equal(isParticipantGroupRoom({...room, additionalMemberIds: ["staff"]}), false);
  assert.equal(
    usesParticipantGroupAccess({...room, hubId: "tampered-scope"}),
    true,
  );
});

test("participant records can use any role but must be active and same-organization", () => {
  const ids = ["owner", "manager", "staff"];
  const records = [
    {id: "owner", orgId: "org-1", role: "platformOwner", isActive: true},
    {id: "manager", orgId: "org-1", role: "managerAdmin", isActive: true},
    {id: "staff", orgId: "org-1", role: "staff", isActive: true},
  ];
  assert.equal(participantRecordsMatchOrganization(ids, "org-1", records), true);
  assert.equal(participantRecordsMatchOrganization(ids, "org-2", records), false);
  assert.equal(participantRecordsMatchOrganization(ids, "org-1", records.slice(0, 2)), false);
  assert.equal(participantRecordsMatchOrganization(ids, "org-1", records.map((record) =>
    record.id === "staff" ? {...record, isActive: false} : record,
  )), false);
});

test("participant comparisons ignore ordering and reject duplicates", () => {
  assert.equal(sameParticipantIds(["a", "b"], ["b", "a"]), true);
  assert.equal(sameParticipantIds(["a", "b"], ["a", "c"]), false);
  assert.equal(sameParticipantIds(["a", "a"], ["a", "a"]), false);
});
