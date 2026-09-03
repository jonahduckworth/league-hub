const assert = require("node:assert/strict");
const test = require("node:test");
const {
  parseArgs,
  profilesWithAddress,
  runMigration,
} = require("../scripts/remove-profile-addresses");

test("profile address cleanup is dry-run by default and requires the exact project", () => {
  assert.deepEqual(parseArgs(["--project", "jdb-league-hub"]), {
    apply: false,
    projectId: "jdb-league-hub",
  });
  assert.deepEqual(parseArgs(["--project=jdb-league-hub", "--apply"]), {
    apply: true,
    projectId: "jdb-league-hub",
  });
  assert.throws(() => parseArgs([]), /confirm the target project/);
  assert.throws(
    () => parseArgs(["--project", "another-project"]),
    /confirm the target project/,
  );
  assert.throws(
    () => parseArgs(["--project", "jdb-league-hub", "--unexpected"]),
    /Unknown argument/,
  );
});

test("profile address cleanup detects field presence without reading its value", () => {
  const documents = [
    {id: "one", data: () => ({address: "123 Main Street"})},
    {id: "two", data: () => ({address: null})},
    {id: "three", data: () => ({phone: "555-0100"})},
  ];

  assert.deepEqual(
    profilesWithAddress({docs: documents}).map((document) => document.id),
    ["one", "two"],
  );
});

function migrationHarness(snapshots) {
  const updates = [];
  const commits = [];
  const collection = {
    get: async () => snapshots.shift(),
  };
  const db = {
    collection: (name) => {
      assert.equal(name, "users");
      return collection;
    },
    batch: () => ({
      update: (ref, patch) => updates.push({ref, patch}),
      commit: async () => commits.push(true),
    }),
  };
  const deleted = Symbol("deleted");
  const admin = {
    apps: [],
    initializeApp: ({projectId}) => {
      assert.equal(projectId, "jdb-league-hub");
      admin.apps.push({});
    },
    firestore: Object.assign(() => db, {
      FieldValue: {delete: () => deleted},
    }),
  };
  return {admin, commits, deleted, updates};
}

test("dry-run reports matching profiles without scheduling writes", async () => {
  const documents = [
    {ref: {id: "one"}, data: () => ({address: "private"})},
    {ref: {id: "two"}, data: () => ({phone: "555-0100"})},
  ];
  const harness = migrationHarness([{docs: documents, size: documents.length}]);
  const logs = [];

  await runMigration({
    admin: harness.admin,
    apply: false,
    projectId: "jdb-league-hub",
    log: (message) => logs.push(JSON.parse(message)),
  });

  assert.deepEqual(logs, [{
    projectId: "jdb-league-hub",
    mode: "dry-run",
    scannedProfiles: 2,
    profilesWithAddress: 1,
  }]);
  assert.equal(harness.updates.length, 0);
  assert.equal(harness.commits.length, 0);
});

test("apply mode deletes in bounded batches and verifies no address fields remain", async () => {
  const documents = Array.from({length: 201}, (_, index) => ({
    ref: {id: `user-${index}`},
    data: () => ({address: index}),
  }));
  const harness = migrationHarness([
    {docs: documents, size: documents.length},
    {docs: [], size: 201},
  ]);

  await runMigration({
    admin: harness.admin,
    apply: true,
    projectId: "jdb-league-hub",
    log: () => undefined,
  });

  assert.equal(harness.updates.length, 201);
  assert.equal(harness.commits.length, 2);
  assert.deepEqual(harness.updates[0].patch, {address: harness.deleted});
});

test("apply mode fails closed when verification still finds an address field", async () => {
  const document = {ref: {id: "one"}, data: () => ({address: "private"})};
  const harness = migrationHarness([
    {docs: [document], size: 1},
    {docs: [document], size: 1},
  ]);

  await assert.rejects(
    runMigration({
      admin: harness.admin,
      apply: true,
      projectId: "jdb-league-hub",
      log: () => undefined,
    }),
    /Verification failed/,
  );
});
