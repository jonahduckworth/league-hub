const assert = require("node:assert/strict");
const test = require("node:test");
const {
  messageReportIdempotencyKey,
  requireSuccessfulMessageReportDelivery,
} = require("../lib/messageReportsLogic");

test("safety report delivery uses a stable retry key", () => {
  assert.equal(
    messageReportIdempotencyKey("org-1", "report-1"),
    "league-hub-report-org-1-report-1",
  );
});

test("safety report delivery failures throw for event retry", () => {
  assert.doesNotThrow(() => requireSuccessfulMessageReportDelivery(202, "ok"));
  assert.throws(
    () => requireSuccessfulMessageReportDelivery(503, "temporarily unavailable"),
    /Safety report delivery failed \(503\)/,
  );
});
