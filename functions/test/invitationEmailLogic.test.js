const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildInvitationEmail,
  classifyInvitationDeliveryFailure,
  invitationExpiresAt,
  invitationIdempotencyKey,
  normalizeInvitationRecipient,
  normalizeInvitationToken,
} = require("../lib/invitationEmailLogic");

test("normalizes valid invitation recipients and rejects malformed addresses", () => {
  assert.equal(normalizeInvitationRecipient("  Coach@Example.COM "), "coach@example.com");
  assert.equal(normalizeInvitationRecipient("coach"), null);
  assert.equal(normalizeInvitationRecipient("coach @example.com"), null);
  assert.equal(normalizeInvitationRecipient(null), null);
});

test("accepts only canonical invitation tokens", () => {
  assert.equal(normalizeInvitationToken(" AABBCCDDEEFF00112233445566778899 "), "aabbccddeeff00112233445566778899");
  assert.equal(normalizeInvitationToken("too-short"), null);
  assert.equal(normalizeInvitationToken("zzbbccddeeff00112233445566778899"), null);
});

test("builds a complete escaped invitation email with acceptance steps", () => {
  const createdAt = new Date("2026-08-12T12:00:00.000Z");
  const email = buildInvitationEmail({
    recipientName: "Chris <Coach>",
    organizationName: "JPHL & Partners",
    invitedByName: "Jonah <Owner>",
    role: "managerAdmin",
    token: "abc123<unsafe>",
    expiresAt: invitationExpiresAt(createdAt),
  });

  assert.equal(email.subject, "You're invited to join JPHL & Partners on League Hub");
  assert.match(email.text, /join JPHL & Partners as Manager/);
  assert.match(email.text, /abc123<unsafe>/);
  assert.match(email.text, /choose Accept Invitation/);
  assert.match(email.text, /expires on August 19, 2026 \(UTC\)/);
  assert.doesNotMatch(email.html, /Chris <Coach>/);
  assert.match(email.html, /Chris &lt;Coach&gt;/);
  assert.match(email.html, /JPHL &amp; Partners/);
  assert.match(email.html, /abc123&lt;unsafe&gt;/);
});

test("derives the authoritative invitation expiry exactly seven days later", () => {
  assert.equal(
    invitationExpiresAt(new Date("2026-08-12T12:00:00.000Z")).toISOString(),
    "2026-08-19T12:00:00.000Z",
  );
});

test("uses a stable bounded idempotency key per invitation", () => {
  const first = invitationIdempotencyKey("org-1", "invite-1");
  assert.equal(first, invitationIdempotencyKey("org-1", "invite-1"));
  assert.notEqual(first, invitationIdempotencyKey("org-1", "invite-2"));
  assert.match(first, /^league-hub-invite-[a-f0-9]{40}$/);
});

test("classifies permanent Resend request failures without retrying", () => {
  for (const [status, name] of [
    [400, "validation_error"],
    [401, "missing_api_key"],
    [403, "invalid_api_key"],
    [422, "invalid_from_address"],
    [451, "security_error"],
  ]) {
    assert.deepEqual(
      classifyInvitationDeliveryFailure(status, JSON.stringify({name})),
      {retryable: false, deliveryStatus: "failed", code: name},
    );
  }
});

test("classifies rate limits, provider outages, and network errors for retry", () => {
  assert.deepEqual(classifyInvitationDeliveryFailure(429, JSON.stringify({
    name: "rate_limit_exceeded",
  })), {
    retryable: true,
    deliveryStatus: "retrying",
    code: "rate_limit_exceeded",
  });
  assert.deepEqual(classifyInvitationDeliveryFailure(503, "unavailable"), {
    retryable: true,
    deliveryStatus: "retrying",
    code: "http_503",
  });
  assert.deepEqual(classifyInvitationDeliveryFailure(null), {
    retryable: true,
    deliveryStatus: "retrying",
    code: "network_error",
  });
});

test("retries only the concurrent idempotency conflict", () => {
  assert.deepEqual(classifyInvitationDeliveryFailure(409, JSON.stringify({
    name: "concurrent_idempotent_requests",
  })), {
    retryable: true,
    deliveryStatus: "retrying",
    code: "concurrent_idempotent_requests",
  });
  assert.deepEqual(classifyInvitationDeliveryFailure(409, JSON.stringify({
    name: "invalid_idempotent_request",
  })), {
    retryable: false,
    deliveryStatus: "failed",
    code: "invalid_idempotent_request",
  });
});

test("stores a bounded fallback code instead of untrusted provider text", () => {
  const failure = classifyInvitationDeliveryFailure(
    400,
    JSON.stringify({name: "unsafe value", message: "secret details"}),
  );
  assert.deepEqual(failure, {
    retryable: false,
    deliveryStatus: "failed",
    code: "http_400",
  });
});
