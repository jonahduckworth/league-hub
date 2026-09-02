const test = require("node:test");
const assert = require("node:assert/strict");

const {
  announcementBatchIdempotencyKey,
  buildAnnouncementEmail,
  classifyAnnouncementDeliveryFailure,
  normalizeAnnouncementRecipient,
} = require("../lib/notifications/announcementEmailLogic");

test("normalizes valid announcement recipients and rejects malformed addresses", () => {
  assert.equal(normalizeAnnouncementRecipient("  COACH@Example.com "), "coach@example.com");
  assert.equal(normalizeAnnouncementRecipient("not-an-email"), null);
  assert.equal(normalizeAnnouncementRecipient(null), null);
});

test("builds an escaped announcement email with a direct app link", () => {
  const message = buildAnnouncementEmail({
    recipientName: "<Coach>",
    organizationName: "JPHL & Friends",
    title: "Practice <Update>",
    body: "Ice time moved.\nBring both jerseys.",
    authorName: "Chris <Admin>",
    scope: "team",
    announcementId: "announcement 1",
    isPinned: true,
  });

  assert.equal(message.subject, "Pinned: Practice <Update>");
  assert.match(message.text, /https:\/\/leaguehub\.ca\/app\/announcements\/announcement%201/);
  assert.match(message.text, /This inbox is not monitored/);
  assert.match(message.html, /Practice &lt;Update&gt;/);
  assert.match(message.html, /JPHL &amp; Friends/);
  assert.match(message.html, /Ice time moved\.<br>Bring both jerseys\./);
  assert.doesNotMatch(message.html, /<Coach>/);
});

test("uses a stable batch idempotency key independent of recipient order", () => {
  const first = announcementBatchIdempotencyKey("org", "announcement", ["u2", "u1"]);
  const second = announcementBatchIdempotencyKey("org", "announcement", ["u1", "u2"]);
  assert.equal(first, second);
  assert.ok(first.length <= 256);
});

test("classifies retryable and permanent Resend failures safely", () => {
  assert.deepEqual(classifyAnnouncementDeliveryFailure(null), {
    retryable: true,
    deliveryStatus: "retrying",
    code: "network_error",
  });
  assert.equal(classifyAnnouncementDeliveryFailure(429).retryable, true);
  assert.equal(classifyAnnouncementDeliveryFailure(503).retryable, true);
  assert.deepEqual(
    classifyAnnouncementDeliveryFailure(422, '{"name":"validation_error"}'),
    {
      retryable: false,
      deliveryStatus: "failed",
      code: "validation_error",
    },
  );
  assert.equal(
    classifyAnnouncementDeliveryFailure(400, "untrusted provider details").code,
    "http_400",
  );
});
