const assert = require("node:assert/strict");
const test = require("node:test");
const {
  canReceiveMessageNotification,
  participantLookupBatches,
  shouldReplaceRoomPreview,
} = require("../lib/notifications/messageLogic");

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
