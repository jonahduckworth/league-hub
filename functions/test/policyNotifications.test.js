const assert = require("node:assert/strict");
const test = require("node:test");
const {isPolicyReady, policyBecameReady} = require("../lib/notifications/policies");

test("policy notifications wait until a reserved upload is finalized", () => {
  assert.equal(isPolicyReady({fileUrl: "", uploadStatus: "uploading"}), false);
  assert.equal(isPolicyReady({fileUrl: "https://example.com/policy.pdf", uploadStatus: "ready"}), true);
});

test("legacy policies with a completed file URL remain notification-ready", () => {
  assert.equal(isPolicyReady({fileUrl: "https://example.com/policy.pdf"}), true);
  assert.equal(isPolicyReady(undefined), false);
});

test("policy transition notifies exactly once when the reserved upload becomes ready", () => {
  const uploading = {fileUrl: "", uploadStatus: "uploading"};
  const ready = {fileUrl: "https://example.com/policy.pdf", uploadStatus: "ready"};
  assert.equal(policyBecameReady(undefined, uploading), false);
  assert.equal(policyBecameReady(uploading, ready), true);
  assert.equal(policyBecameReady(ready, ready), false);
  assert.equal(policyBecameReady(ready, undefined), false);
});
