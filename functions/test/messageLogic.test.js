const assert = require("node:assert/strict");
const test = require("node:test");
const {
  canReceiveMessageNotification,
  chatNotificationDeliveryGroups,
  notificationLookupIds,
  participantLookupBatches,
  shouldUseExplicitParticipantRecipients,
  shouldReplaceRoomPreview,
  visibleMessageNotification,
  visibleRoomPreview,
} = require("../lib/notifications/messageLogic");

test("chat pushes use a binary badge unless the recipient disabled it", () => {
  assert.deepEqual(chatNotificationDeliveryGroups([
    {fcmTokens: ["a-1", "a-2"]},
    {fcmTokens: ["b-1"], appBadgeEnabled: false},
    {fcmTokens: [null, "c-1", 4]},
  ]), [
    {tokens: ["a-1", "a-2", "c-1"], badge: 1},
    {tokens: ["b-1"]},
  ]);
});

test("message notifications respect room scope and blocked senders", () => {
  const staff = {
    role: "staff",
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
    blockedUserIds: [],
    orgId: "org-1",
    isActive: true,
  };
  assert.equal(canReceiveMessageNotification(
    staff, "sender", "league", "hub-1", "league-1", "org-1",
  ), true);
  assert.equal(canReceiveMessageNotification(
    {...staff, blockedUserIds: ["sender"]},
    "sender", "league", "hub-1", "league-1", "org-1",
  ), false);
  assert.equal(canReceiveMessageNotification(
    staff, "sender", "league", "other-hub", "league-1", "org-1",
  ), false);
  assert.equal(canReceiveMessageNotification(
    staff, "sender", "event", "hub-1", "league-1", "org-1", "team-1",
  ), true);
  assert.equal(canReceiveMessageNotification(
    staff, "sender", "event", "other-hub", "league-1", "org-1", "other-team",
  ), false);
  assert.equal(canReceiveMessageNotification(
    staff, "sender", "direct",
  ), true);
  assert.equal(canReceiveMessageNotification(
    {...staff, blockedUserIds: ["sender"]}, "sender", "direct",
  ), false);
  assert.equal(canReceiveMessageNotification(
    {...staff, orgId: "other-org"},
    "sender", "direct", undefined, undefined, "org-1",
  ), false);
  assert.equal(canReceiveMessageNotification(
    {...staff, isActive: false},
    "sender", "direct", undefined, undefined, "org-1",
  ), false);
});

test("room previews ignore out-of-order trigger delivery", () => {
  assert.equal(shouldReplaceRoomPreview(null, null, 100, "a"), true);
  assert.equal(shouldReplaceRoomPreview(200, "b", 100, "a"), false);
  assert.equal(shouldReplaceRoomPreview(100, "a", 200, "b"), true);
  assert.equal(shouldReplaceRoomPreview(100, "b", 100, "a"), false);
  assert.equal(shouldReplaceRoomPreview(100, "a", 100, "b"), true);
});

test("participant-only room metadata never exposes message previews or senders", () => {
  assert.deepEqual(
    visibleRoomPreview("participants", "Private Sender", "private-id", "Private text"),
    {
      lastMessage: "New message",
      lastMessageBy: null,
      lastMessageSenderId: null,
    },
  );
  assert.deepEqual(
    visibleRoomPreview("scope", "Visible Sender", "visible-id", "Visible text"),
    {
      lastMessage: "Visible text",
      lastMessageBy: "Visible Sender",
      lastMessageSenderId: "visible-id",
    },
  );
});

test("participant-only notification delivery logs never expose private content", () => {
  assert.deepEqual(
    visibleMessageNotification(
      "participants",
      "event",
      "Private Group",
      "Private Sender",
      "Private text",
    ),
    {title: "Private Group", body: "New message"},
  );
  assert.deepEqual(
    visibleMessageNotification(
      "scope",
      "event",
      "Team Room",
      "Visible Sender",
      "Visible text",
    ),
    {title: "Team Room", body: "Visible Sender: Visible text"},
  );
  assert.deepEqual(
    visibleMessageNotification(
      undefined,
      "direct",
      "Direct Room",
      "Visible Sender",
      "Visible text",
    ),
    {title: "Visible Sender", body: "Visible text"},
  );
});

test("elevated users also receive no notification from blocked senders", () => {
  assert.equal(canReceiveMessageNotification(
    {role: "platformOwner", blockedUserIds: ["sender"]},
    "sender",
    "league",
  ), false);
  assert.equal(canReceiveMessageNotification(
    {role: "superAdmin"},
    "sender",
    "league",
  ), true);
});

test("participant notification lookups stay within Firestore limits", () => {
  const ids = Array.from({length: 65}, (_, index) => `user-${index}`);
  const batches = participantLookupBatches([...ids, "user-1"]);
  assert.deepEqual(batches.map((batch) => batch.length), [30, 30, 5]);
  assert.equal(new Set(batches.flat()).size, 65);
});

test("multi-team rooms resolve recipients from current organization assignments", () => {
  assert.equal(
    shouldUseExplicitParticipantRecipients(["original-member"], ["team-1"]),
    false,
  );
  assert.equal(
    shouldUseExplicitParticipantRecipients(["direct-member"], []),
    true,
  );
  assert.equal(
    shouldUseExplicitParticipantRecipients([], [], "participants"),
    true,
  );
});

test("participant-only Group Chats notify exact selected people regardless of assignments", () => {
  const participant = {
    role: "staff",
    orgId: "org-1",
    isActive: true,
  };
  assert.equal(canReceiveMessageNotification(
    participant,
    "sender",
    "event",
    "__participant_group__",
    undefined,
    "org-1",
    "__participant_group__",
    [],
    [],
    [],
    "staff-1",
    "participants",
  ), true);
  assert.deepEqual(
    notificationLookupIds(
      ["staff-1", "admin-1", "staff-1"],
      ["outsider-1"],
      "event",
      "participants",
    ),
    ["staff-1", "admin-1"],
  );
});

test("multi-team notifications reach every selected team and selected-Hub managers", () => {
  const hubIds = ["hub-1", "hub-2"];
  const teamIds = ["team-1", "team-2"];
  assert.equal(canReceiveMessageNotification(
    {
      role: "staff",
      teamIds: ["team-2"],
      orgId: "org-1",
      isActive: true,
    },
    "sender", "event", "hub-1", "league-1", "org-1", "team-1",
    hubIds, teamIds,
  ), true);
  assert.equal(canReceiveMessageNotification(
    {
      role: "managerAdmin",
      hubIds: ["hub-2"],
      orgId: "org-1",
      isActive: true,
    },
    "sender", "event", "hub-1", "league-1", "org-1", "team-1",
    hubIds, teamIds,
  ), true);
  assert.equal(canReceiveMessageNotification(
    {
      role: "staff",
      hubIds: ["hub-2"],
      orgId: "org-1",
      isActive: true,
    },
    "sender", "event", "hub-1", "league-1", "org-1", "team-1",
    hubIds, teamIds,
  ), false);
  assert.equal(canReceiveMessageNotification(
    {
      role: "staff",
      teamIds: ["team-3"],
      orgId: "org-1",
      isActive: true,
    },
    "sender", "event", "hub-1", "league-1", "org-1", "team-1",
    hubIds, teamIds,
  ), false);
});

test("room-specific members receive managed-room notifications only", () => {
  const unassignedStaff = {
    role: "staff",
    orgId: "org-1",
    isActive: true,
  };
  assert.equal(canReceiveMessageNotification(
    unassignedStaff,
    "sender",
    "event",
    "hub-1",
    "league-1",
    "org-1",
    "team-1",
    [],
    [],
    ["league-staff"],
    "league-staff",
  ), true);
  assert.equal(canReceiveMessageNotification(
    unassignedStaff,
    "sender",
    "event",
    "hub-1",
    "league-1",
    "org-1",
    "team-1",
    [],
    [],
    ["other-user"],
    "league-staff",
  ), false);
  assert.equal(canReceiveMessageNotification(
    unassignedStaff,
    "sender",
    "direct",
    undefined,
    undefined,
    "org-1",
    undefined,
    [],
    [],
    ["league-staff"],
    "league-staff",
  ), true);
});

test("notification lookups union additional members for managed rooms", () => {
  assert.deepEqual(notificationLookupIds(
    ["participant", "shared"],
    ["additional", "shared"],
    "event",
  ), ["participant", "shared", "additional"]);
  assert.deepEqual(notificationLookupIds(
    ["participant"],
    ["forged-additional"],
    "direct",
  ), ["participant"]);
});
