const test = require("node:test");
const assert = require("node:assert/strict");

const {
  matchRampDirectory,
  parseRampDirectory,
} = require("../lib/schedule/rampDiscovery");
const {
  CURRENT_SEASON_ID,
  RAMP_DIVISION_IDS,
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

  assert.equal(configured.length, 50);
  const result = matchRampDirectory(parseRampDirectory(`${headings}\n${routes}`), configured);
  assert.equal(result.status, "matched");
  assert.equal(result.discoveredSeasonId, CURRENT_SEASON_ID);
  assert.equal(result.matchedTeams, 50);
  assert.deepEqual(result.divisionIds, RAMP_DIVISION_IDS);
});
