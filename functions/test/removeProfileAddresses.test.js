const assert = require("node:assert/strict");
const test = require("node:test");
const {
  parseArgs,
  profilesWithAddress,
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
