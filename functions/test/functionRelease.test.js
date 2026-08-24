const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  classifyChangedFiles,
  normalizeTargets,
  parseReleasePlan,
  validateAutomaticPlan,
  validateTargetsAgainstExports,
  verifyDeployment,
} = require("../scripts/function-release");

const targetedPlan = {
  all: false,
  targets: ["adminCreatePolicy"],
  reason: "Deploy the updated policy creation callable.",
};

test("classifies workflow changes as validation-only", () => {
  assert.deepEqual(
    classifyChangedFiles([".github/workflows/deploy-functions.yml"]),
    {
      functionsValidate: true,
      functionsDeploy: false,
      rulesValidate: true,
      rulesDeploy: false,
      adminValidate: true,
      adminDeploy: false,
      marketingValidate: true,
      marketingDeploy: false,
    },
  );
});

test("keeps Functions validation in the gate for admin changes", () => {
  const classification = classifyChangedFiles(["apps/admin/src/lib/callables.ts"]);
  assert.equal(classification.functionsValidate, true);
  assert.equal(classification.functionsDeploy, false);
  assert.equal(classification.adminValidate, true);
  assert.equal(classification.adminDeploy, true);
  assert.equal(classification.rulesDeploy, false);
});

test("validates and deploys Firestore, Storage, and index changes", () => {
  for (const file of ["firestore.rules", "storage.rules", "firestore.indexes.json"]) {
    const classification = classifyChangedFiles([file]);
    assert.equal(classification.rulesValidate, true, file);
    assert.equal(classification.rulesDeploy, true, file);
    assert.equal(classification.functionsDeploy, false, file);
  }
});

test("validates Firebase configuration without forcing an all-Functions release", () => {
  const classification = classifyChangedFiles(["firebase.json"]);
  assert.equal(classification.functionsValidate, true);
  assert.equal(classification.functionsDeploy, false);
  assert.equal(classification.rulesValidate, true);
  assert.equal(classification.rulesDeploy, true);
  assert.equal(classification.adminDeploy, true);
  assert.equal(classification.marketingDeploy, true);
});

test("pins Storage rules to the app's existing Firebase bucket", () => {
  const firebaseConfig = JSON.parse(fs.readFileSync(
    path.resolve(__dirname, "../../firebase.json"),
    "utf8",
  ));
  assert.deepEqual(firebaseConfig.storage, [{
    bucket: "jdb-league-hub.firebasestorage.app",
    rules: "storage.rules",
    target: "primary",
  }]);
});

test("requires an updated targeted release plan for Functions source changes", () => {
  assert.throws(
    () => validateAutomaticPlan(["functions/src/admin.ts"], targetedPlan),
    /without updating functions\/release-plan.json/,
  );
  assert.equal(
    validateAutomaticPlan([
      "functions/src/admin.ts",
      "functions/release-plan.json",
    ], targetedPlan).functionsDeploy,
    true,
  );
});

test("requires all-functions intent for shared runtime changes", () => {
  assert.throws(
    () => validateAutomaticPlan([
      "functions/package-lock.json",
      "functions/release-plan.json",
    ], targetedPlan),
    /require an explicit all-functions release/,
  );
});

test("validates release plan schema and target names", () => {
  assert.deepEqual(parseReleasePlan(JSON.stringify(targetedPlan)), targetedPlan);
  assert.throws(
    () => parseReleasePlan(JSON.stringify({...targetedPlan, reason: "short"})),
    /must explain the release/,
  );
  assert.throws(() => normalizeTargets("valid,bad-name"), /Invalid Function deploy target/);
  assert.throws(() => normalizeTargets("valid,valid"), /must not contain duplicates/);
});

test("refuses targets that are not exported by the built Functions entrypoint", () => {
  assert.doesNotThrow(() => validateTargetsAgainstExports(
    ["adminCreatePolicy"],
    ["adminCreatePolicy", "adminUpdatePolicy"],
  ));
  assert.throws(
    () => validateTargetsAgainstExports(["missingFunction"], ["adminCreatePolicy"]),
    /Unknown Function exports: missingFunction/,
  );
});

test("verifies deployed target state, runtime, and region", () => {
  const functionsList = {
    status: "success",
    result: [{
      id: "adminCreatePolicy",
      state: "ACTIVE",
      runtime: "nodejs22",
      region: "us-central1",
    }],
  };
  assert.deepEqual(verifyDeployment({
    functionsList,
    targets: ["adminCreatePolicy"],
    expectedRuntime: "nodejs22",
    expectedRegion: "us-central1",
  }), [{
    id: "adminCreatePolicy",
    state: "ACTIVE",
    runtime: "nodejs22",
    region: "us-central1",
  }]);
  assert.throws(
    () => verifyDeployment({
      functionsList,
      targets: ["adminCreatePolicy"],
      expectedRuntime: "nodejs20",
      expectedRegion: "us-central1",
    }),
    /not nodejs20/,
  );
});
