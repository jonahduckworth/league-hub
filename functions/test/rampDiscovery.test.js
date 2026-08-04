const test = require("node:test");
const assert = require("node:assert/strict");

const {
  matchRampDirectory,
  parseRampDirectory,
} = require("../lib/schedule/rampDiscovery");

const configured = [
  { id: "wolves-17", name: "17U AAA - Wolves HC", ageGroup: "17U" },
  { id: "rockies-17", name: "17U AAA - Calgary Rockies", ageGroup: "17U" },
  { id: "wolves-18", name: "18U AAA - Wolves HC", ageGroup: "18U" },
];

function directoryHtml(seasonId = "12322") {
  return `
    <a href="/team/${seasonId}/0/23859/319142/masterschedule" class="item">
      <img alt="17U AAA - Calgary Rockies"><p>17U AAA - Calgary Rockies</p>
    </a>
    <a href="/team/${seasonId}/0/23859/319163/masterschedule">
      <p>17U AAA - Wolves HC</p>
    </a>
    <a href="/team/${seasonId}/0/16622/319170/masterschedule">
      <p>18U AAA - Wolves HC</p>
    </a>
  `;
}

test("parses and deduplicates public RAMP team schedule routes", () => {
  const html = `${directoryHtml()}${directoryHtml()}`;
  const teams = parseRampDirectory(html);

  assert.equal(teams.length, 3);
  assert.deepEqual(teams[0], {
    seasonId: "12322",
    divisionId: "23859",
    teamId: "319142",
    name: "17U AAA - Calgary Rockies",
  });
});

test("matches an exact League Hub structure and derives routing IDs", () => {
  const result = matchRampDirectory(parseRampDirectory(directoryHtml("99999")), configured);

  assert.equal(result.status, "matched");
  assert.equal(result.discoveredSeasonId, "99999");
  assert.deepEqual(result.divisionIds, { "17U": "23859", "18U": "16622" });
  assert.deepEqual(result.assignments, [
    { configuredTeamId: "wolves-17", sourceDivisionId: "23859", sourceTeamId: "319163" },
    { configuredTeamId: "rockies-17", sourceDivisionId: "23859", sourceTeamId: "319142" },
    { configuredTeamId: "wolves-18", sourceDivisionId: "16622", sourceTeamId: "319170" },
  ]);
});

test("rejects incomplete or expanded structures instead of switching seasons", () => {
  const missing = matchRampDirectory(
    parseRampDirectory(directoryHtml().replace(/<a href="\/team\/12322\/0\/16622[\s\S]*?<\/a>/, "")),
    configured,
  );
  const extra = matchRampDirectory(parseRampDirectory(`${directoryHtml()}
    <a href="/team/12322/0/23859/400000/masterschedule"><p>17U AAA - New Club</p></a>`), configured);

  assert.equal(missing.status, "rejected");
  assert.match(missing.message, /matched 2 of 3/);
  assert.equal(extra.status, "rejected");
  assert.match(extra.message, /exact structure match/);
});

test("rejects ambiguous pages that expose multiple complete seasons", () => {
  const result = matchRampDirectory(
    parseRampDirectory(`${directoryHtml("12322")}${directoryHtml("99999")}`),
    configured,
  );

  assert.equal(result.status, "rejected");
  assert.match(result.message, /multiple complete seasons/);
});

test("decodes HTML entities in team names", () => {
  const discovered = parseRampDirectory(`
    <a href="/team/12322/0/1/2/masterschedule"><p>17U AAA - Smith &amp; Jones HC</p></a>
  `);
  const result = matchRampDirectory(discovered, [
    { id: "smith-jones", name: "17U AAA - Smith & Jones HC", ageGroup: "17U" },
  ]);

  assert.equal(result.status, "matched");
});
