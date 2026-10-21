const assert = require("node:assert/strict");
const test = require("node:test");
const helpers = require("../lib/helpers");
const {onTeamUpdated} = require("../lib/notifications/teams");

const user = (role, overrides = {}) => ({
  role, orgId: "org", isActive: true, fcmTokens: [`${role}-token`], ...overrides,
});
const users = [
  user("platformOwner"), user("superAdmin"), user("managerAdmin"), user("staff"),
  user("superAdmin", {isActive: false, fcmTokens: ["inactive"]}),
  user("superAdmin", {orgId: "other", fcmTokens: ["outside-organization"]}),
];

function query(records, conditions = []) {
  return {
    where(field, operator, value) {
      assert.ok(["==", "in"].includes(operator));
      return query(records, [...conditions, {field, operator, value}]);
    },
    async get() {
      return {docs: records.filter(record => conditions.every(({field, operator, value}) =>
        operator === "in" ? value.includes(record[field]) : record[field] === value,
      )).map(record => ({data: () => record}))};
    },
  };
}

async function run(t, before, after, records = users) {
  const sent = [];
  t.mock.method(helpers.db, "collection", name => {
    assert.equal(name, "users");
    return query(records);
  });
  t.mock.method(helpers, "sendNotification", async (...args) => sent.push(args));
  await onTeamUpdated.run({
    params: {orgId: "org", leagueId: "league", hubId: "hub", teamId: "team"},
    data: {before: {data: () => before}, after: {data: () => after}},
  });
  return sent;
}

for (const [action, before, after, title] of [
  ["creation", undefined, {name: "Other Division Team"}, "New Team Added"],
  ["rename", {name: "Old name"}, {name: "Other Division Team"}, "Team Updated"],
  ["deletion", {name: "Other Division Team"}, undefined, "Team Removed"],
]) {
  test(`team ${action} alerts only active same-org Owner/Admin users`, async t => {
    const sent = await run(t, before, after);
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0][0], ["platformOwner-token", "superAdmin-token"]);
    assert.equal(sent[0][1].title, title);
    assert.deepEqual(sent[0][2], {type: "team_update", orgId: "org"});
  });
}

test("unrelated team edits do not produce alerts", async t => {
  assert.deepEqual(await run(t, {name: "Team"}, {name: "Team", logoUrl: "updated"}), []);
});

test("Staff/Manager-only organizations produce no recipient tokens", async t => {
  const sent = await run(t, undefined, {name: "Team"}, [user("staff"), user("managerAdmin")]);
  assert.deepEqual(sent[0][0], []);
});

test("malformed or empty admin device-token values are skipped", async t => {
  const sent = await run(t, undefined, {name: "Team"}, [
    user("platformOwner", {fcmTokens: "not-an-array"}),
    user("superAdmin", {fcmTokens: [null, 3, "", "valid-admin-token"]}),
  ]);
  assert.deepEqual(sent[0][0], ["valid-admin-token"]);
});
