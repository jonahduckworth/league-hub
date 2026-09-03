const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildImportPlan,
  invitationDocumentId,
  manifestSha256,
  parseArgs,
  validateManifest,
} = require("../scripts/import-jphl-invitations");

function manifest(overrides = {}) {
  return {
    version: 1,
    importId: "jphl-contacts-2026-27",
    projectId: "jdb-league-hub",
    orgId: "org-1",
    orgName: "JPHL",
    leagueId: "league-1",
    leagueName: "Junior Prospects Hockey League",
    source: {sheet: "Sheet1", range: "A1:G139"},
    expected: {
      sourceRows: 1,
      skippedMissingEmail: 0,
      skippedExistingUsers: 0,
      consolidatedDuplicateRows: 0,
      inviteCount: 1,
      hubCount: 3,
      teamCount: 2,
      leagueWideCount: 0,
      hubOnlyCount: 0,
      teamScopedCount: 1,
    },
    invitations: [{
      email: "Coach@Example.com",
      displayName: "Casey Coach",
      title: "Head Coach",
      role: "staff",
      assignments: [
        {hubName: "Hub One", ageGroups: ["14u"]},
        {hubName: "Hub Two", ageGroups: []},
      ],
      sourceRows: [2],
    }],
    ...overrides,
  };
}

function state(overrides = {}) {
  return {
    projectId: "jdb-league-hub",
    org: {id: "org-1", name: "JPHL"},
    league: {id: "league-1", name: "Junior Prospects Hockey League"},
    hubs: [
      {id: "hub-1", name: "Hub One"},
      {id: "hub-2", name: "Hub Two"},
      {id: "hub-3", name: "Hub Three"},
    ],
    teams: [
      {id: "team-1", hubId: "hub-1", ageGroup: "14U"},
      {id: "team-2", hubId: "hub-2", ageGroup: "18U"},
    ],
    users: [],
    invitations: [],
    markerExists: false,
    ...overrides,
  };
}

test("validates and resolves a deterministic invitation plan", () => {
  const plan = buildImportPlan(manifest(), state());
  assert.equal(plan.invitations.length, 1);
  assert.equal(plan.invitations[0].email, "coach@example.com");
  assert.deepEqual(plan.invitations[0].leagueIds, ["league-1"]);
  assert.deepEqual(plan.invitations[0].hubIds, ["hub-1", "hub-2"]);
  assert.deepEqual(plan.invitations[0].teamIds, ["team-1"]);
  assert.equal(
    plan.invitations[0].id,
    invitationDocumentId("jphl-contacts-2026-27", "coach@example.com"),
  );
});

test("manifest fingerprints are stable across object key order", () => {
  assert.equal(manifestSha256({a: 1, b: 2}), manifestSha256({b: 2, a: 1}));
  assert.notEqual(manifestSha256({a: 1}), manifestSha256({a: 2}));
});

test("fails closed for duplicates, elevated roles, blank titles, and count drift", () => {
  const base = manifest();
  assert.throws(() => validateManifest({
    ...base,
    expected: {...base.expected, inviteCount: 2},
    invitations: [base.invitations[0], {...base.invitations[0]}],
  }), /Duplicate invitation email/);
  assert.throws(() => validateManifest({
    ...base,
    invitations: [{...base.invitations[0], role: "superAdmin"}],
  }), /Only staff invitations/);
  assert.throws(() => validateManifest({
    ...base,
    invitations: [{...base.invitations[0], title: " "}],
  }), /title is required/);
  assert.throws(() => validateManifest({
    ...base,
    expected: {...base.expected, inviteCount: 2},
  }), /contains 1 invitations, expected 2/);
});

test("fails closed when production identity or structure drifts", () => {
  assert.throws(() => buildImportPlan(manifest(), state({projectId: "other"})), /Connected project/);
  assert.throws(() => buildImportPlan(manifest(), state({org: {id: "org-1", name: "Other"}})), /Expected organization/);
  assert.throws(() => buildImportPlan(manifest(), state({hubs: []})), /Expected 3 hubs/);
  assert.throws(() => buildImportPlan(manifest(), state({teams: []})), /Expected 2 teams/);
  assert.throws(() => buildImportPlan(manifest(), state({markerExists: true})), /already exists/);
});

test("refuses existing users, pending invitations, and unmatched assignments", () => {
  assert.throws(() => buildImportPlan(
    manifest(),
    state({users: [{email: "coach@example.com"}]}),
  ), /existing user/);
  assert.throws(() => buildImportPlan(
    manifest(),
    state({invitations: [{email: "coach@example.com", status: "pending"}]}),
  ), /Pending invitation/);
  assert.throws(() => buildImportPlan(
    manifest(),
    state({invitations: [{
      id: invitationDocumentId("jphl-contacts-2026-27", "coach@example.com"),
      email: "old@example.com",
      status: "expired",
    }]}),
  ), /document already exists/);
  const badHub = manifest();
  badHub.invitations[0].assignments[0].hubName = "Unknown";
  assert.throws(() => buildImportPlan(badHub, state()), /Unknown live hub/);
  const badTeam = manifest();
  badTeam.invitations[0].assignments[0].ageGroups = ["17U"];
  assert.throws(() => buildImportPlan(badTeam, state()), /Unknown 17U team/);
});

test("apply mode requires explicit independent confirmations", () => {
  const dryRun = parseArgs(["--manifest", "/tmp/manifest.json"]);
  assert.deepEqual(dryRun, {apply: false, manifestPath: "/tmp/manifest.json"});
  const apply = parseArgs([
    "--manifest", "/tmp/manifest.json",
    "--apply",
    "--confirm-import-id", "jphl-contacts-2026-27",
    "--expected-create-count", "130",
    "--confirm-manifest-sha256", "abc123",
  ]);
  assert.equal(apply.apply, true);
  assert.equal(apply.expectedCreateCount, 130);
  assert.throws(() => parseArgs(["--manifest", "relative.json"]), /absolute path/);
  assert.throws(() => parseArgs(["--manifest", "/tmp/a.json", "--yes"]), /Unknown argument/);
});
