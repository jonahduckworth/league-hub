const test = require("node:test");
const assert = require("node:assert/strict");

const {
  existingSourceSeasonId,
  isSuspiciousScheduleDrop,
  parseRampCalendar,
  reconcileSchedule,
} = require("../lib/schedule/rampLogic");

const sourceSeasonId = "12322";

test("assigns legacy records to the persisted season during discovery", () => {
  assert.equal(existingSourceSeasonId(undefined, "previous-season"), "previous-season");
  assert.equal(existingSourceSeasonId("stored-season", "previous-season"), "stored-season");
});

function reconciliationOptions(overrides = {}) {
  return {
    sourceSeasonId,
    allowRemovals: true,
    ...overrides,
  };
}

const rampCalendar = `BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VEVENT\r
DESCRIPTION:Final: 1 - 7\r
DTEND;TZID=America/Edmonton:20250919T174500\r
DTSTAMP:20260804T211527Z\r
DTSTART;TZID=America/Edmonton:20250919T153000\r
LOCATION:Cavendish Farm Centre East\\, 74 Mauretania Road West\\, Lethbridge\r
 \\, AB\\, T1J 5A8\r
SUMMARY:17U AAA: 17U AAA - Wolves HC vs 17U AAA - Calgary Rockies\r
UID:leaguegame-1613636@rampinteractive.com\r
END:VEVENT\r
BEGIN:VEVENT\r
DTEND;TZID=America/Edmonton:20250920T120000\r
DTSTART;TZID=America/Edmonton:20250920T110000\r
SUMMARY:Wolves HC Practice\r
UID:practice-99@rampinteractive.com\r
END:VEVENT\r
END:VCALENDAR`;

function incoming(overrides = {}) {
  return {
    sourceSeasonId,
    sourceUid: "leaguegame-200@rampinteractive.com",
    sourceGameId: "200",
    startsAt: new Date("2026-09-10T01:00:00.000Z"),
    endsAt: new Date("2026-09-10T03:00:00.000Z"),
    timezone: "America/Edmonton",
    division: "17U AAA",
    firstTeamName: "Wolves HC",
    secondTeamName: "Calgary Rockies",
    title: "Wolves HC vs Calgary Rockies",
    location: "Great Plains Arena",
    status: "scheduled",
    firstTeamId: "wolves",
    secondTeamId: "rockies",
    teamIds: ["wolves", "rockies"],
    hubIds: ["hub-wolves", "hub-rockies"],
    leagueIds: ["jphl"],
    ...overrides,
  };
}

function existing(overrides = {}) {
  return {
    id: "league-hub-event-1",
    sourceSeasonId,
    sourceUid: "leaguegame-100@rampinteractive.com",
    previousSourceUids: [],
    startsAt: new Date("2026-09-10T01:00:00.000Z"),
    firstTeamName: "Wolves HC",
    secondTeamName: "Calgary Rockies",
    title: "Wolves HC vs Calgary Rockies",
    location: "Great Plains Arena",
    firstTeamId: "wolves",
    secondTeamId: "rockies",
    teamIds: ["wolves", "rockies"],
    hubIds: ["hub-wolves", "hub-rockies"],
    leagueIds: ["jphl"],
    isActive: true,
    ...overrides,
  };
}

test("parses RAMP game feeds, folded locations, local times, and final scores", () => {
  const events = parseRampCalendar(rampCalendar, "America/Edmonton");

  assert.equal(events.length, 1);
  assert.equal(events[0].sourceGameId, "1613636");
  assert.equal(events[0].startsAt.toISOString(), "2025-09-19T21:30:00.000Z");
  assert.equal(events[0].endsAt.toISOString(), "2025-09-19T23:45:00.000Z");
  assert.equal(events[0].firstTeamName, "17U AAA - Wolves HC");
  assert.equal(events[0].secondTeamName, "17U AAA - Calgary Rockies");
  assert.equal(events[0].location, "Cavendish Farm Centre East, 74 Mauretania Road West, Lethbridge, AB, T1J 5A8");
  assert.equal(events[0].status, "final");
  assert.equal(events[0].firstScore, 1);
  assert.equal(events[0].secondScore, 7);
});

test("updates an existing event when RAMP keeps its UID", () => {
  const current = existing({ sourceUid: "leaguegame-200@rampinteractive.com" });
  const result = reconcileSchedule(
    [current],
    [incoming({ location: "Updated Arena" })],
    reconciliationOptions(),
  );

  assert.deepEqual(result.counts, { added: 0, updated: 1, replaced: 0, removed: 0 });
  assert.equal(result.upserts[0].id, current.id);
  assert.equal(result.upserts[0].event.location, "Updated Arena");
});

test("rebinds a deleted and recreated RAMP game to the stable League Hub event ID", () => {
  const current = existing();
  const replacement = incoming({
    sourceUid: "leaguegame-999@rampinteractive.com",
    sourceGameId: "999",
    startsAt: new Date("2026-09-10T02:00:00.000Z"),
    location: "Updated Great Plains Arena",
  });
  const result = reconcileSchedule([current], [replacement], reconciliationOptions());

  assert.deepEqual(result.counts, { added: 0, updated: 0, replaced: 1, removed: 0 });
  assert.equal(result.upserts[0].id, current.id);
  assert.deepEqual(result.upserts[0].previousSourceUids, [current.sourceUid]);
});

test("soft-removes genuinely missing games only when removals are allowed", () => {
  const current = existing();
  const guarded = reconcileSchedule(
    [current],
    [],
    reconciliationOptions({ allowRemovals: false }),
  );
  const complete = reconcileSchedule([current], [], reconciliationOptions());

  assert.equal(guarded.removals.length, 0);
  assert.equal(complete.removals[0].id, current.id);
  assert.equal(complete.counts.removed, 1);
});

test("does not rebind an unrelated game", () => {
  const result = reconcileSchedule([existing()], [incoming({
    firstTeamName: "Island HC",
    secondTeamName: "Okanagan HC",
    title: "Island HC vs Okanagan HC",
    teamIds: ["island", "okanagan"],
    startsAt: new Date("2026-10-20T01:00:00.000Z"),
  })], reconciliationOptions());

  assert.equal(result.counts.added, 1);
  assert.equal(result.counts.removed, 1);
  assert.notEqual(result.upserts[0].id, "league-hub-event-1");
});

test("does not rebind repeat opponents outside the replacement time window", () => {
  const result = reconcileSchedule([existing()], [incoming({
    sourceUid: "leaguegame-999@rampinteractive.com",
    sourceGameId: "999",
    startsAt: new Date("2027-02-10T01:00:00.000Z"),
    endsAt: new Date("2027-02-10T03:00:00.000Z"),
  })], reconciliationOptions());

  assert.equal(result.counts.added, 1);
  assert.equal(result.counts.replaced, 0);
  assert.equal(result.counts.removed, 1);
  assert.notEqual(result.upserts[0].id, "league-hub-event-1");
});

test("rebinds a recreated game after an intervening missing sync", () => {
  const now = new Date("2026-09-01T12:00:00.000Z");
  const current = existing();
  const missingSync = reconcileSchedule(
    [current],
    [],
    reconciliationOptions({ now }),
  );
  assert.equal(missingSync.removals[0].id, current.id);

  const tombstone = existing({
    isActive: false,
    sourceMissingSince: now,
  });
  const replacement = incoming({
    sourceUid: "leaguegame-999@rampinteractive.com",
    sourceGameId: "999",
  });
  const result = reconcileSchedule(
    [tombstone],
    [replacement],
    reconciliationOptions({ now: new Date("2026-09-01T18:00:00.000Z") }),
  );

  assert.deepEqual(result.counts, { added: 0, updated: 0, replaced: 1, removed: 0 });
  assert.equal(result.upserts[0].id, tombstone.id);
  assert.deepEqual(result.upserts[0].previousSourceUids, [tombstone.sourceUid]);
});

test("does not reuse a stale inactive game as a replacement candidate", () => {
  const current = existing({
    isActive: false,
    sourceMissingSince: new Date("2026-08-01T00:00:00.000Z"),
  });
  const result = reconcileSchedule(
    [current],
    [incoming({ sourceUid: "leaguegame-999@rampinteractive.com" })],
    reconciliationOptions({ now: new Date("2026-09-01T00:00:00.000Z") }),
  );

  assert.equal(result.counts.added, 1);
  assert.equal(result.counts.replaced, 0);
});

test("preserves both team scopes when one of two team feeds fails", () => {
  const current = existing();
  const onlySuccessfulFeed = incoming({
    sourceUid: current.sourceUid,
    secondTeamId: undefined,
    teamIds: ["wolves"],
    hubIds: ["hub-wolves"],
  });
  const result = reconcileSchedule(
    [current],
    [onlySuccessfulFeed],
    reconciliationOptions({
      allowRemovals: false,
      preserveExistingScope: true,
    }),
  );

  assert.deepEqual(result.upserts[0].event.teamIds, ["wolves", "rockies"]);
  assert.equal(result.upserts[0].event.firstTeamId, "wolves");
  assert.equal(result.upserts[0].event.secondTeamId, "rockies");
  assert.deepEqual(result.upserts[0].event.hubIds, ["hub-wolves", "hub-rockies"]);
  assert.deepEqual(result.upserts[0].event.leagueIds, ["jphl"]);
});

test("preserves ordered team IDs when RAMP reverses the matchup during a partial sync", () => {
  const current = existing();
  const reversedFeed = incoming({
    sourceUid: current.sourceUid,
    firstTeamName: "Calgary Rockies",
    secondTeamName: "Wolves HC",
    title: "Calgary Rockies vs Wolves HC",
    firstTeamId: undefined,
    secondTeamId: "wolves",
    teamIds: ["wolves"],
    hubIds: ["hub-wolves"],
  });
  const result = reconcileSchedule(
    [current],
    [reversedFeed],
    reconciliationOptions({
      allowRemovals: false,
      preserveExistingScope: true,
    }),
  );

  assert.equal(result.upserts[0].event.firstTeamId, "rockies");
  assert.equal(result.upserts[0].event.secondTeamId, "wolves");
});

test("keeps historical games active when a different season is synchronized", () => {
  const historical = existing({
    id: "historical-game",
    sourceSeasonId: "previous-season",
    sourceUid: "leaguegame-50@rampinteractive.com",
  });
  const current = existing({ sourceUid: "leaguegame-200@rampinteractive.com" });
  const result = reconcileSchedule(
    [historical, current],
    [incoming()],
    reconciliationOptions(),
  );

  assert.deepEqual(result.counts, { added: 0, updated: 1, replaced: 0, removed: 0 });
  assert.equal(result.upserts[0].id, current.id);
  assert.equal(result.removals.some((event) => event.id === historical.id), false);
});

test("only removes missing games from the season being synchronized", () => {
  const historical = existing({
    id: "historical-game",
    sourceSeasonId: "previous-season",
  });
  const current = existing({ id: "current-game" });
  const result = reconcileSchedule(
    [historical, current],
    [],
    reconciliationOptions(),
  );

  assert.deepEqual(result.removals.map((event) => event.id), [current.id]);
});

test("does not match identical RAMP UIDs across seasons", () => {
  const historical = existing({
    id: "historical-game",
    sourceSeasonId: "previous-season",
    sourceUid: "leaguegame-200@rampinteractive.com",
  });
  const result = reconcileSchedule(
    [historical],
    [incoming()],
    reconciliationOptions(),
  );

  assert.equal(result.counts.added, 1);
  assert.notEqual(result.upserts[0].id, historical.id);
  assert.equal(result.removals.length, 0);
});

test("rejects incoming events from a different season", () => {
  assert.throws(
    () => reconcileSchedule(
      [],
      [incoming({ sourceSeasonId: "other-season" })],
      reconciliationOptions(),
    ),
    /multiple seasons/,
  );
});

test("guards suspicious schedule drops without rounding small seasons down", () => {
  assert.equal(isSuspiciousScheduleDrop(1, 0), true);
  assert.equal(isSuspiciousScheduleDrop(3, 1), true);
  assert.equal(isSuspiciousScheduleDrop(20, 12), true);
  assert.equal(isSuspiciousScheduleDrop(20, 13), false);
  assert.equal(isSuspiciousScheduleDrop(0, 0), false);
});
