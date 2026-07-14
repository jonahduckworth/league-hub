const assert = require("node:assert/strict");
const test = require("node:test");
const {
  assignableRoles,
  canAccessOrg,
  canCreateLeague,
  canManageTarget,
  isValidAnnouncementTarget,
  isValidPolicyCategory,
  normalizeStringArray,
  outranks,
} = require("../lib/adminLogic");

test("platform owners and super admins can access the admin org scope correctly", () => {
  assert.equal(canAccessOrg({ id: "owner", role: "platformOwner", isActive: true }, "org-2"), true);
  assert.equal(canAccessOrg({ id: "admin", role: "superAdmin", orgId: "org-1", isActive: true }, "org-1"), true);
  assert.equal(canAccessOrg({ id: "admin", role: "superAdmin", orgId: "org-1", isActive: true }, "org-2"), false);
  assert.equal(canAccessOrg({ id: "manager", role: "managerAdmin", orgId: "org-1", isActive: true }, "org-1"), false);
});

test("only active platform owners can create leagues", () => {
  assert.equal(canCreateLeague({ id: "owner", role: "platformOwner", isActive: true }), true);
  assert.equal(canCreateLeague({ id: "owner", role: "platformOwner", isActive: false }), false);
  assert.equal(canCreateLeague({ id: "admin", role: "superAdmin", isActive: true }), false);
  assert.equal(canCreateLeague({ id: "manager", role: "managerAdmin", isActive: true }), false);
  assert.equal(canCreateLeague({ id: "staff", role: "staff", isActive: true }), false);
});

test("announcement targets require a league and the correct nested IDs", () => {
  assert.equal(isValidAnnouncementTarget({ scope: "league", leagueId: "l1", hubId: null, teamId: null }), true);
  assert.equal(isValidAnnouncementTarget({ scope: "hub", leagueId: "l1", hubId: "h1", teamId: null }), true);
  assert.equal(isValidAnnouncementTarget({ scope: "team", leagueId: "l1", hubId: "h1", teamId: "t1" }), true);
  assert.equal(isValidAnnouncementTarget({ scope: "league", leagueId: "" }), false);
  assert.equal(isValidAnnouncementTarget({ scope: "hub", leagueId: "l1" }), false);
  assert.equal(isValidAnnouncementTarget({ scope: "team", leagueId: "l1", hubId: "h1" }), false);
  assert.equal(isValidAnnouncementTarget({ scope: "all", leagueId: "l1" }), false);
});

test("policy categories match the mobile policy taxonomy", () => {
  for (const category of ["Policy", "Protocol", "Code of Conduct", "Other"]) {
    assert.equal(isValidPolicyCategory(category), true);
  }
  assert.equal(isValidPolicyCategory("General"), false);
  assert.equal(isValidPolicyCategory("Safety"), false);
});

test("role hierarchy matches mobile permission behavior", () => {
  assert.equal(outranks("platformOwner", "superAdmin"), true);
  assert.equal(outranks("superAdmin", "managerAdmin"), true);
  assert.equal(outranks("superAdmin", "superAdmin"), false);
  assert.deepEqual(assignableRoles("platformOwner"), ["superAdmin", "managerAdmin", "staff"]);
  assert.deepEqual(assignableRoles("superAdmin"), ["managerAdmin", "staff"]);
});

test("admin user management follows self, org, and hierarchy restrictions", () => {
  assert.equal(
    canManageTarget(
      { id: "owner", role: "platformOwner", isActive: true },
      { id: "admin", role: "superAdmin", orgId: "org-2" },
    ),
    true,
  );
  assert.equal(
    canManageTarget(
      { id: "admin", role: "superAdmin", orgId: "org-1", isActive: true },
      { id: "staff", role: "staff", orgId: "org-1" },
    ),
    true,
  );
  assert.equal(
    canManageTarget(
      { id: "admin", role: "superAdmin", orgId: "org-1", isActive: true },
      { id: "peer", role: "superAdmin", orgId: "org-1" },
    ),
    false,
  );
  assert.equal(
    canManageTarget(
      { id: "admin", role: "superAdmin", orgId: "org-1", isActive: true },
      { id: "staff", role: "staff", orgId: "org-2" },
    ),
    false,
  );
});

test("normalizes string arrays for hub and team assignment inputs", () => {
  assert.deepEqual(normalizeStringArray([" a ", "a", "", 3, "b"]), ["a", "b"]);
  assert.deepEqual(normalizeStringArray(null), []);
});
