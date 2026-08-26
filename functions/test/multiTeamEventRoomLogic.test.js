const assert = require("node:assert/strict");
const test = require("node:test");
const {
  belongsToMultiTeamEventRoomAudience,
  canCreateMultiTeamEventRoom,
  maximumMultiTeamEventRoomTeams,
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
