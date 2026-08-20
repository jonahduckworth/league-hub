const assert = require("node:assert/strict");
const test = require("node:test");

const adminFunctions = require("../lib/admin");

test("exports separate V1 and V2 policy creation callables", () => {
  assert.equal(typeof adminFunctions.adminCreatePolicy, "function");
  assert.equal(typeof adminFunctions.adminCreatePolicyV2, "function");
  assert.notEqual(adminFunctions.adminCreatePolicy, adminFunctions.adminCreatePolicyV2);
});
