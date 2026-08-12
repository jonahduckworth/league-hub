const assert = require("node:assert/strict");
const test = require("node:test");
const {
  accountAvatarPath,
  accountDeletionBlockedByOwnership,
  accountDeletionUserMatches,
  hasRecentAuthentication,
  isMissingAuthUserError,
} = require("../lib/accountDeletionLogic");

test("account deletion only accepts the authenticated user's profile", () => {
  assert.equal(accountDeletionUserMatches("user-1", {id: "user-1"}), true);
  assert.equal(accountDeletionUserMatches("user-1", {id: "user-2"}), false);
  assert.equal(accountDeletionUserMatches("user-1", undefined), false);
});

test("account deletion requires a current authentication time", () => {
  assert.equal(hasRecentAuthentication(undefined, 1_000), false);
  assert.equal(hasRecentAuthentication(600, 1_000), false);
  assert.equal(hasRecentAuthentication(700, 1_000), true);
  assert.equal(hasRecentAuthentication(1_001, 1_000), false);
});

test("organization owners must transfer ownership before deletion", () => {
  assert.equal(accountDeletionBlockedByOwnership(
    "owner",
    {id: "owner", role: "platformOwner"},
    "owner",
  ), true);
  assert.equal(accountDeletionBlockedByOwnership(
    "owner",
    {id: "owner", role: "staff"},
    "owner",
  ), true);
  assert.equal(accountDeletionBlockedByOwnership(
    "staff",
    {id: "staff", role: "staff"},
    "owner",
  ), false);
});

test("account deletion only targets the user's canonical avatar", () => {
  assert.equal(
    accountAvatarPath("user-1", {orgId: "org-1", avatarUrl: "https://example.com/avatar"}),
    "orgs/org-1/avatars/user-1.jpg",
  );
  assert.equal(accountAvatarPath("user-1", {orgId: "org-1"}), null);
  assert.equal(accountAvatarPath("user-1", {avatarUrl: "https://example.com/avatar"}), null);
});

test("account deletion retries only tolerate an already removed Auth user", () => {
  assert.equal(isMissingAuthUserError({code: "auth/user-not-found"}), true);
  assert.equal(isMissingAuthUserError({code: "auth/internal-error"}), false);
  assert.equal(isMissingAuthUserError(new Error("network")), false);
});
