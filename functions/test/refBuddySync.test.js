const assert = require("node:assert/strict");
const test = require("node:test");
const { integrationFromOrg, signedHeaders } = require("../lib/schedule/refBuddySync");

test("validates scoped Ref Buddy mappings", () => {
  assert.equal(integrationFromOrg({ refBuddyScheduleIntegration: { enabled: true, teamMappings: [] } }), undefined);
  assert.equal(integrationFromOrg({ refBuddyScheduleIntegration: { enabled: true, teamMappings: [{
    refBuddyLeagueId: "league-rb", refBuddyTeamId: "team-rb", leagueId: "league-lh", hubId: "hub", teamId: "team-lh",
  }] } }).teamMappings[0].teamId, "team-lh");
});

test("signs the exact request body", () => {
  const headers = signedHeaders("secret", "{}", new Date("2026-09-01T12:00:00Z"));
  assert.equal(headers["X-RefBuddy-Timestamp"], "1788264000");
  assert.equal(headers["X-RefBuddy-Signature"], "cb09a23214e084108029c36781adff9cb54741f85776995a4b4ecc4cfd79f1b2");
});
