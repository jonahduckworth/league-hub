const assert = require("node:assert/strict");
const test = require("node:test");
const {
  belongsToMultiTeamEventRoomAudience,
  canCreateMultiTeamEventRoom,
  canEditMultiTeamEventRoomAudience,
  existingEventRoomAudience,
  maximumMultiTeamEventRoomTeams,
  sameMultiTeamAudience,
} = require("../lib/multiTeamEventRoomLogic");

const targets = [
  {hubId: "hub-1", teamId: "team-1"},
  {hubId: "hub-2", teamId: "team-2"},
];

test("multi-team creation requires all Team assignments or all Hub assignments", () => {
  assert.equal(canCreateMultiTeamEventRoom({role: "superAdmin"}, targets), true);
  assert.equal(canCreateMultiTeamEventRoom({
    role: "managerAdmin",
    hubIds: ["hub-1", "hub-2"],
  }, targets), true);
  assert.equal(canCreateMultiTeamEventRoom({
    role: "managerAdmin",
    teamIds: ["team-1", "team-2"],
  }, targets), true);
  assert.equal(canCreateMultiTeamEventRoom({
    role: "managerAdmin",
    hubIds: ["hub-1"],
    teamIds: ["team-2"],
  }, targets), false);
  assert.equal(canCreateMultiTeamEventRoom({
    role: "managerAdmin",
    hubIds: ["hub-1"],
    teamIds: [],
  }, targets), false);
  assert.equal(canCreateMultiTeamEventRoom({role: "staff"}, targets), false);
});

test("multi-team audience includes selected teams and selected-Hub managers only", () => {
  assert.equal(belongsToMultiTeamEventRoomAudience({
    id: "team-member",
    role: "staff",
    orgId: "org-1",
    isActive: true,
    teamIds: ["team-2"],
  }, "org-1", targets), true);
  assert.equal(belongsToMultiTeamEventRoomAudience({
    id: "hub-manager",
    role: "managerAdmin",
    orgId: "org-1",
    isActive: true,
    hubIds: ["hub-2"],
  }, "org-1", targets), true);
  assert.equal(belongsToMultiTeamEventRoomAudience({
    id: "hub-staff",
    role: "staff",
    orgId: "org-1",
    isActive: true,
    hubIds: ["hub-2"],
  }, "org-1", targets), false);
  assert.equal(belongsToMultiTeamEventRoomAudience({
    id: "other-org",
    role: "managerAdmin",
    orgId: "org-2",
    isActive: true,
    hubIds: ["hub-2"],
  }, "org-1", targets), false);
});

test("multi-team Event Rooms use the documented 50-team limit", () => {
  assert.equal(maximumMultiTeamEventRoomTeams, 50);
});

test("only active Platform Owners and same-organization Admins can edit audiences", () => {
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "platformOwner",
    isActive: true,
  }, "org-1"), true);
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "superAdmin",
    orgId: "org-1",
    isActive: true,
  }, "org-1"), true);
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "superAdmin",
    orgId: "org-2",
    isActive: true,
  }, "org-1"), false);
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "managerAdmin",
    orgId: "org-1",
    isActive: true,
  }, "org-1"), false);
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "staff",
    orgId: "org-1",
    isActive: true,
  }, "org-1"), false);
  assert.equal(canEditMultiTeamEventRoomAudience({
    role: "platformOwner",
    isActive: false,
  }, "org-1"), false);
});

test("audience comparisons ignore ordering but reject drift and duplicates", () => {
  assert.equal(sameMultiTeamAudience(["team-1", "team-2"], ["team-2", "team-1"]), true);
  assert.equal(sameMultiTeamAudience(["team-1"], ["team-2"]), false);
  assert.equal(sameMultiTeamAudience(["team-1", "team-1"], ["team-1", "team-2"]), false);
});

test("existing Event Room audiences normalize multi-team and legacy scopes", () => {
  assert.deepEqual(existingEventRoomAudience({
    teamIds: ["team-1", "team-2"],
    teamId: "__multi_team__",
    hubId: "__multi_team__",
  }), {
    teamIds: ["team-1", "team-2"],
    scopeKey: "multi",
    legacy: false,
  });
  assert.deepEqual(existingEventRoomAudience({teamId: "team-1", hubId: "hub-1"}), {
    teamIds: ["team-1"],
    scopeKey: "team:team-1",
    legacy: true,
  });
  assert.deepEqual(existingEventRoomAudience({hubId: "hub-1"}), {
    teamIds: [],
    scopeKey: "hub:hub-1",
    legacy: true,
  });
  assert.deepEqual(existingEventRoomAudience({}), {
    teamIds: [],
    scopeKey: "league",
    legacy: true,
  });
});

test("malformed stored Event Room audiences fail closed", () => {
  assert.equal(existingEventRoomAudience({teamIds: "team-1"}), null);
  assert.equal(existingEventRoomAudience({teamIds: ["team-1", "team-1"]}), null);
  assert.equal(existingEventRoomAudience({teamId: "__multi_team__"}), null);
  assert.equal(existingEventRoomAudience({hubId: "__multi_team__"}), null);
});
