const assert = require("node:assert/strict");
const test = require("node:test");
const { integrationFromOrg, localFields, reconciliationPlan, scheduleWindow, signedHeaders } = require("../lib/schedule/refBuddySync");

test("validates scoped Ref Buddy mappings", () => {
  assert.equal(integrationFromOrg({ refBuddyScheduleIntegration: { enabled: true, teamMappings: [] } }), undefined);
  assert.equal(integrationFromOrg({ refBuddyScheduleIntegration: { enabled: true, teamMappings: [{
    refBuddyLeagueId: "league-rb", refBuddyTeamId: "team-rb", leagueId: "league-lh", hubId: "hub", teamId: "team-lh",
  }] } }).teamMappings[0].teamId, "team-lh");
});

test("uses each canonical game timezone, including dates that differ by zone", () => {
  const instant = new Date("2026-09-02T06:30:00Z");
  assert.deepEqual(localFields(instant, "America/Vancouver"), {
    localDate: "2026-09-01", localStartTime: "23:30",
  });
  assert.deepEqual(localFields(instant, "America/Edmonton"), {
    localDate: "2026-09-02", localStartTime: "00:30",
  });
});

test("reconciliation deactivates only Ref Buddy events absent from a complete response", () => {
  assert.deepEqual(
    reconciliationPlan(["refbuddy-old", "refbuddy-still"], ["refbuddy-still", "refbuddy-new"]),
    ["refbuddy-old"],
  );
});

test("canonical request window stays within the backend 400-day limit", () => {
  const window = scheduleWindow(new Date("2026-09-01T12:00:00Z"));
  assert.equal((window.to.getTime() - window.from.getTime()) / 86400000, 399);
  assert.equal(window.from.toISOString(), "2026-03-05T12:00:00.000Z");
  assert.equal(window.to.toISOString(), "2027-04-08T12:00:00.000Z");
});

test("signs the exact request body", () => {
  const headers = signedHeaders("secret", "{}", new Date("2026-09-01T12:00:00Z"));
  assert.equal(headers["X-RefBuddy-Timestamp"], "1788264000");
  assert.equal(headers["X-RefBuddy-Signature"], "cb09a23214e084108029c36781adff9cb54741f85776995a4b4ecc4cfd79f1b2");
});
