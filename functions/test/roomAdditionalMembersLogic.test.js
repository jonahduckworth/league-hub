const assert = require("node:assert/strict");
const test = require("node:test");
const {
  existingAdditionalMemberIds,
  isAdditionalRoomMemberCandidate,
  isRoomEligibleForAdditionalMembers,
  maximumAdditionalRoomMembers,
  sameAdditionalMemberIds,
} = require("../lib/roomAdditionalMembersLogic");

test("only Team Rooms and Event Rooms support additional members", () => {
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "league",
    teamId: "team-1",
    isArchived: false,
  }), true);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "event",
    roomPurpose: "event",
    isArchived: false,
  }), true);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "event",
    isArchived: false,
  }), true);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "event",
    roomPurpose: "group",
  }), false);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "league",
    teamId: null,
  }), false);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "direct",
  }), false);
  assert.equal(isRoomEligibleForAdditionalMembers({
    type: "event",
    isArchived: true,
  }), false);
});

test("candidates are active non-admin users without Team or Hub assignments", () => {
  const base = {role: "staff", orgId: "org-1", isActive: true};
  assert.equal(isAdditionalRoomMemberCandidate(base, "org-1"), true);
  assert.equal(isAdditionalRoomMemberCandidate({
    ...base,
    role: "managerAdmin",
    hubIds: [],
    teamIds: [],
  }, "org-1"), true);
  assert.equal(isAdditionalRoomMemberCandidate({...base, hubIds: ["hub-1"]}, "org-1"), false);
  assert.equal(isAdditionalRoomMemberCandidate({...base, teamIds: ["team-1"]}, "org-1"), false);
  assert.equal(isAdditionalRoomMemberCandidate({...base, role: "superAdmin"}, "org-1"), false);
  assert.equal(isAdditionalRoomMemberCandidate({...base, orgId: "org-2"}, "org-1"), false);
  assert.equal(isAdditionalRoomMemberCandidate({...base, isActive: false}, "org-1"), false);
});

test("stored additional member IDs are bounded, unique, and backward compatible", () => {
  assert.equal(maximumAdditionalRoomMembers, 50);
  assert.deepEqual(existingAdditionalMemberIds({}), []);
  assert.deepEqual(existingAdditionalMemberIds({
    additionalMemberIds: ["member-1", "member-2"],
  }), ["member-1", "member-2"]);
  assert.equal(existingAdditionalMemberIds({additionalMemberIds: "member-1"}), null);
  assert.equal(existingAdditionalMemberIds({
    additionalMemberIds: ["member-1", "member-1"],
  }), null);
  assert.equal(existingAdditionalMemberIds({
    additionalMemberIds: Array.from({length: 51}, (_, index) => `member-${index}`),
  }), null);
});

test("additional member comparisons tolerate ordering but detect drift", () => {
  assert.equal(sameAdditionalMemberIds(
    ["member-1", "member-2"],
    ["member-2", "member-1"],
  ), true);
  assert.equal(sameAdditionalMemberIds(["member-1"], ["member-2"]), false);
});
