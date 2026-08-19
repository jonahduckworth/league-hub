const test = require("node:test");
const assert = require("node:assert/strict");

const {
  matchRampDirectory,
  parseRampDirectory,
} = require("../lib/schedule/rampDiscovery");
const {
  CURRENT_SEASON_ID,
  RAMP_DIVISION_IDS,
  assignmentPatch,
  buildTeamPlan,
  hubs,
} = require("../scripts/reconcile-jphl-structure");

test("production structure exactly matches the current RAMP directory shape", () => {
  const headings = Object.entries(RAMP_DIVISION_IDS)
    .map(([ageGroup, divisionId]) =>
      `<button id="accordion-menu-title-${divisionId}"><span>${ageGroup} AAA</span></button>`)
    .join("\n");
  const routes = hubs.flatMap((hub) => hub.teams.map((team) =>
    `<a href="/team/${CURRENT_SEASON_ID}/0/${RAMP_DIVISION_IDS[team.ageGroup]}/${team.sourceId}/masterschedule"><p>${hub.name}</p></a>`))
    .join("\n");
  const configured = hubs.flatMap((hub) => hub.teams.map((team) => ({
    id: team.id,
    name: team.name,
    ageGroup: team.ageGroup,
  })));

  assert.equal(configured.length, 49);
  const result = matchRampDirectory(parseRampDirectory(`${headings}\n${routes}`), configured);
  assert.equal(result.status, "matched");
  assert.equal(result.discoveredSeasonId, CURRENT_SEASON_ID);
  assert.equal(result.matchedTeams, 49);
  assert.deepEqual(result.divisionIds, RAMP_DIVISION_IDS);
});

function desiredExistingTeams() {
  return hubs.flatMap((hub) => hub.teams.map((team) => ({
    id: team.id,
    hubId: hub.id,
    name: team.name,
    ageGroup: team.ageGroup,
    sourceTeamId: team.sourceId,
  })));
}

test("production reconciliation preserves existing team IDs and moves Junior Capitals safely", () => {
  const existing = desiredExistingTeams()
    .filter((team) => ![
      "jphl_hub_bellingham_hc",
      "jphl_hub_cowichan_jr_capitals",
      "jphl_hub_velocity_ha",
    ].includes(team.hubId))
    .map((team) => ({ ...team, id: `legacy_${team.sourceTeamId}` }));
  const epic = existing.find((team) => team.sourceTeamId === "398242");
  epic.name = "18U AAA - EPIC HA";
  existing.push({
    id: "jphl_team_319161",
    hubId: "jphl_hub_island_hc",
    name: "18U AAA - Junior Capitals",
    ageGroup: "18U",
    sourceTeamId: "319161",
  });

  const plan = buildTeamPlan(existing);
  assert.equal(existing.length, 47);
  assert.equal(plan.items.filter((item) => item.kind === "update").length, 46);
  assert.equal(plan.items.filter((item) => item.kind === "move").length, 1);
  assert.equal(plan.items.filter((item) => item.kind === "create").length, 2);
  assert.equal(plan.retired.length, 0);

  const capitals = plan.items.find((item) => item.target.sourceId === "398241");
  assert.equal(capitals.kind, "move");
  assert.equal(capitals.targetId, "jphl_team_319161");
  assert.equal(capitals.target.hubId, "jphl_hub_cowichan_jr_capitals");

  assert.deepEqual(assignmentPatch({
    hubIds: ["jphl_hub_island_hc"],
    teamIds: ["jphl_team_319161"],
  }, plan), {
    hubIds: ["jphl_hub_island_hc", "jphl_hub_cowichan_jr_capitals"],
  });
});

test("production reconciliation is idempotent and recognizes only approved retired routes", () => {
  const exact = desiredExistingTeams();
  const idempotent = buildTeamPlan(exact);
  assert.equal(idempotent.items.length, 49);
  assert(idempotent.items.every((item) => item.kind === "update"));
  assert.equal(idempotent.retired.length, 0);

  const withRetired = buildTeamPlan([
    ...exact,
    {
      id: "jphl_team_398209",
      hubId: "jphl_hub_okanagan_hc",
      name: "14U AAA - Okanagan HC",
      ageGroup: "14U",
      sourceTeamId: "398209",
    },
    {
      id: "jphl_team_398250",
      hubId: "jphl_hub_victoria_ha",
      name: "18U AAA - Victoria HA",
      ageGroup: "18U",
      sourceTeamId: "398250",
    },
  ]);
  assert.deepEqual(withRetired.retired.map((team) => team.id), [
    "jphl_team_398209",
    "jphl_team_398250",
  ]);
});

test("production reconciliation fails closed for an unexpected team", () => {
  assert.throws(() => buildTeamPlan([{
    id: "unexpected",
    hubId: "jphl_hub_bow_valley_hc",
    name: "16U AAA - Unknown HC",
    ageGroup: "16U",
    sourceTeamId: "999999",
  }]), /Refusing to remove unexpected team/);
});
