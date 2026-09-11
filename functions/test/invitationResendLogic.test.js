const assert = require("node:assert/strict");
const test = require("node:test");
const {
  invitationCanBeResent,
  invitationIsActivePending,
  invitationIsExpired,
  invitationReplacementData,
  maximumBulkInvitationResends,
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
  assert.equal(maximumBulkInvitationResends, 100);
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
