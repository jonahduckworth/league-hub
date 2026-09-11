const assert = require("node:assert/strict");
const test = require("node:test");
const {
  invitationCanBeResent,
  invitationIsActivePending,
  invitationIsExpired,
  invitationResendBatches,
  invitationResendBatchSize,
  invitationReplacementData,
  resendableExpiredInvitationIds,
} = require("../lib/invitationResendLogic");

test("classifies active, elapsed, and manually expired invitations", () => {
  const now = Date.parse("2026-08-12T12:00:00.000Z");
  assert.equal(invitationIsActivePending({status: "pending", expiresAt: "2026-08-13T12:00:00.000Z"}, now), true);
  assert.equal(invitationIsExpired({status: "pending", expiresAt: "2026-08-11T12:00:00.000Z"}, now), true);
  assert.equal(invitationIsExpired({status: "expired"}, now), true);
  assert.equal(invitationIsExpired({status: "accepted", expiresAt: "2026-08-01T12:00:00.000Z"}, now), false);
  assert.equal(invitationCanBeResent({status: "pending"}), true);
  assert.equal(invitationCanBeResent({status: "expired"}), true);
  assert.equal(invitationCanBeResent({status: "accepted"}), false);
  assert.equal(invitationResendBatchSize, 100);
});

test("selects only the authoritative expired invitation per normalized email", () => {
  const now = Date.parse("2026-08-12T12:00:00.000Z");
  const invitations = [
    {id: "old", email: "Coach@Example.com", status: "expired", createdAt: "2026-08-01T00:00:00.000Z"},
    {id: "latest", email: "coach@example.com", status: "pending", createdAt: "2026-08-02T00:00:00.000Z", expiresAt: "2026-08-09T00:00:00.000Z"},
    {id: "active-pending", email: "official@example.com", status: "pending", expiresAt: "2026-08-13T00:00:00.000Z"},
    {id: "expired-with-active", email: "OFFICIAL@example.com", status: "expired", createdAt: "2026-08-01T00:00:00.000Z"},
    {id: "joined", email: "joined@example.com", status: "expired", createdAt: "2026-08-03T00:00:00.000Z"},
  ];
  const users = [{email: "JOINED@EXAMPLE.COM", isActive: true}];

  assert.deepEqual(resendableExpiredInvitationIds(invitations, users, now), ["latest"]);
});

test("breaks identical invitation timestamps deterministically", () => {
  const now = Date.parse("2026-08-12T12:00:00.000Z");
  const invitations = [
    {id: "invite-a", email: "coach@example.com", status: "expired", createdAt: "2026-08-01T00:00:00.000Z"},
    {id: "invite-b", email: "COACH@example.com", status: "expired", createdAt: "2026-08-01T00:00:00.000Z"},
  ];

  assert.deepEqual(resendableExpiredInvitationIds(invitations, [], now), ["invite-b"]);
});

test("splits more than one hundred resends without dropping any invitations", () => {
  const invitationIds = Array.from({length: 205}, (_, index) => `invite-${index}`);
  const batches = invitationResendBatches(invitationIds);

  assert.deepEqual(batches.map((batch) => batch.length), [100, 100, 5]);
  assert.deepEqual(batches.flat(), invitationIds);
});

test("builds a fresh pending invitation for a resend", () => {
  const replacement = invitationReplacementData({
    orgId: "org-1",
    email: "coach@example.com",
    displayName: "Coach New",
    title: "Head Coach",
    role: "managerAdmin",
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
    invitedBy: "owner-1",
    invitedByName: "League Owner",
    createdAt: "new-created-at",
    expiresAt: "new-expires-at",
    token: "fresh-token",
    replacesInvitationId: "old-invite",
  });

  assert.deepEqual(replacement, {
    orgId: "org-1",
    email: "coach@example.com",
    displayName: "Coach New",
    title: "Head Coach",
    role: "managerAdmin",
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
    invitedBy: "owner-1",
    invitedByName: "League Owner",
    createdAt: "new-created-at",
    expiresAt: "new-expires-at",
    status: "pending",
    token: "fresh-token",
    emailDeliveryStatus: "pending",
    suppressAdminNotification: true,
    replacesInvitationId: "old-invite",
  });
});
