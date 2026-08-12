const test = require("node:test");
const assert = require("node:assert/strict");

const {scopeAssociationEvents} = require("../lib/schedule/rampScope");

const teams = [
  {id: "edmonton-18", hubId: "edmonton", leagueId: "jphl", name: "18U AAA - HC Edmonton", ageGroup: "18U"},
  {id: "langley-18", hubId: "langley", leagueId: "jphl", name: "18U AAA - Langley HA", ageGroup: "18U"},
  {id: "island-18", hubId: "island", leagueId: "jphl", name: "18U AAA - Island HC", ageGroup: "18U"},
];

function event(overrides = {}) {
  return {
    sourceUid: "leaguegame-1@rampinteractive.com",
    startsAt: new Date("2022-09-22T19:00:00.000Z"),
    endsAt: new Date("2022-09-22T21:00:00.000Z"),
    timezone: "America/Edmonton",
    division: "18U AAA",
    firstTeamName: "U18 HC Edmonton",
    secondTeamName: "U18 Langley Hockey Academy",
    title: "U18 HC Edmonton vs U18 Langley Hockey Academy",
    status: "final",
    ...overrides,
  };
}

test("scopes an association archive event without historical RAMP team IDs", () => {
  const [scoped] = scopeAssociationEvents([event()], "6114", teams);

  assert.equal(scoped.sourceSeasonId, "6114");
  assert.equal(scoped.firstTeamId, "edmonton-18");
  assert.equal(scoped.secondTeamId, "langley-18");
  assert.deepEqual(scoped.teamIds, ["edmonton-18", "langley-18"]);
  assert.deepEqual(scoped.hubIds, ["edmonton", "langley"]);
  assert.deepEqual(scoped.leagueIds, ["jphl"]);
});

test("maps the archived Island Wild name to the current Island HC hub", () => {
  const [scoped] = scopeAssociationEvents([event({
    firstTeamName: "U18 Island Wild",
    secondTeamName: "U18 HC Edmonton",
  })], "6114", teams);

  assert.deepEqual(scoped.teamIds, ["island-18", "edmonton-18"]);
  assert.equal(scoped.firstTeamId, "island-18");
  assert.equal(scoped.secondTeamId, "edmonton-18");
});

test("keeps league scope for archived placeholders and retired teams", () => {
  const [scoped] = scopeAssociationEvents([event({
    firstTeamName: "1st Seed U18 AB Pool",
    secondTeamName: "U18 Retired Academy",
  })], "6114", teams);

  assert.deepEqual(scoped.teamIds, []);
  assert.equal(scoped.firstTeamId, undefined);
  assert.equal(scoped.secondTeamId, undefined);
  assert.deepEqual(scoped.hubIds, []);
  assert.deepEqual(scoped.leagueIds, ["jphl"]);
});
