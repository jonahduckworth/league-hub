const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildInvitationEmail,
  invitationIdempotencyKey,
  normalizeInvitationRecipient,
  normalizeInvitationToken,
  requireSuccessfulInvitationDelivery,
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
  const email = buildInvitationEmail({
    recipientName: "Chris <Coach>",
    organizationName: "JPHL & Partners",
    invitedByName: "Jonah <Owner>",
    role: "managerAdmin",
    token: "abc123<unsafe>",
  });

  assert.equal(email.subject, "You're invited to join JPHL & Partners on League Hub");
  assert.match(email.text, /join JPHL & Partners as Manager/);
  assert.match(email.text, /abc123<unsafe>/);
  assert.match(email.text, /choose Accept Invitation/);
  assert.match(email.text, /expires after 7 days/);
  assert.doesNotMatch(email.html, /Chris <Coach>/);
  assert.match(email.html, /Chris &lt;Coach&gt;/);
  assert.match(email.html, /JPHL &amp; Partners/);
  assert.match(email.html, /abc123&lt;unsafe&gt;/);
});

test("uses a stable bounded idempotency key per invitation", () => {
  const first = invitationIdempotencyKey("org-1", "invite-1");
  assert.equal(first, invitationIdempotencyKey("org-1", "invite-1"));
  assert.notEqual(first, invitationIdempotencyKey("org-1", "invite-2"));
  assert.match(first, /^league-hub-invite-[a-f0-9]{40}$/);
});

test("delivery guard accepts success and throws retryable failures", () => {
  assert.doesNotThrow(() => requireSuccessfulInvitationDelivery(202, "ok"));
  assert.throws(
    () => requireSuccessfulInvitationDelivery(503, "temporary outage"),
    /Invitation email delivery failed \(503\)/,
  );
});
