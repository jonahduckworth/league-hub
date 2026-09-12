const assert = require("node:assert/strict");
const test = require("node:test");
const {
  unreadChatDeliveryGroups,
  unreadRecipientIds,
} = require("../lib/notifications/unreadChatAccounting");

test("unread recipients exclude the sender and existing readers", () => {
  assert.deepEqual(
    unreadRecipientIds(
      ["reader-a", "reader-b", "reader-a", "sender"],
      ["sender", "reader-b"],
    ),
    ["reader-a"],
  );
});

test("notification delivery groups preserve exact per-user badge totals", () => {
  assert.deepEqual(unreadChatDeliveryGroups([
    {userId: "a", tokens: ["a-1"], badgeCount: 2},
    {userId: "b", tokens: ["b-1", "b-2"], badgeCount: 5},
    {userId: "c", tokens: ["c-1"]},
    {userId: "d", tokens: ["d-1"], badgeCount: 2},
  ]), [
    {tokens: ["a-1", "d-1"], badge: 2},
    {tokens: ["b-1", "b-2"], badge: 5},
    {tokens: ["c-1"], badge: undefined},
  ]);
});
