const assert = require("node:assert/strict");
const test = require("node:test");
const {
  invitationReplacementData,
} = require("../lib/invitationResendLogic");

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
