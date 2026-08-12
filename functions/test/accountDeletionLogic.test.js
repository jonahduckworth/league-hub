const assert = require("node:assert/strict");
const test = require("node:test");
const {
  accountAvatarPath,
  accountDeletionUserMatches,
} = require("../lib/accountDeletionLogic");

test("account deletion only accepts the authenticated user's profile", () => {
  assert.equal(accountDeletionUserMatches("user-1", {id: "user-1"}), true);
  assert.equal(accountDeletionUserMatches("user-1", {id: "user-2"}), false);
  assert.equal(accountDeletionUserMatches("user-1", undefined), false);
});

test("account deletion only targets the user's canonical avatar", () => {
  assert.equal(
    accountAvatarPath("user-1", {orgId: "org-1", avatarUrl: "https://example.com/avatar"}),
    "orgs/org-1/avatars/user-1.jpg",
  );
  assert.equal(accountAvatarPath("user-1", {orgId: "org-1"}), null);
  assert.equal(accountAvatarPath("user-1", {avatarUrl: "https://example.com/avatar"}), null);
});
