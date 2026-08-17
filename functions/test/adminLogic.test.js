const assert = require("node:assert/strict");
const test = require("node:test");
const {
  assignableRoles,
  canAccessOrg,
  canCreateLeague,
  canManageInvitationRole,
  canManageTarget,
  canManageTargetAssignments,
  isManagedChatRoomType,
  initialPolicyUploadMode,
  isOrganizationWidePolicyTarget,
  isValidAnnouncementTarget,
  isValidPolicyCategory,
  nullableStringPatch,
  normalizeStringArray,
  outranks,
  teamMemberRecordsMatchOrg,
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

test("admin policy uploads are organization-wide only", () => {
  assert.equal(isOrganizationWidePolicyTarget({}), true);
  assert.equal(isOrganizationWidePolicyTarget({leagueId: null, hubId: null, teamId: null}), true);
  assert.equal(isOrganizationWidePolicyTarget({leagueId: "l1"}), false);
  assert.equal(isOrganizationWidePolicyTarget({leagueId: "l1", hubId: "h1"}), false);
  assert.equal(isOrganizationWidePolicyTarget({leagueId: "l1", hubId: "h1", teamId: "t1"}), false);
});

test("policy upload reservation remains compatible with the released admin", () => {
  assert.equal(initialPolicyUploadMode(undefined), "uploading");
  assert.equal(initialPolicyUploadMode(""), "uploading");
  assert.equal(initialPolicyUploadMode("https://example.com/policy.pdf"), "ready");
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

test("peer admins can manage assignments without gaining full user control", () => {
  const actor = {
    id: "admin",
    role: "superAdmin",
    orgId: "org-1",
    isActive: true,
  };
  assert.equal(
    canManageTargetAssignments(actor, {
      id: "peer",
      role: "superAdmin",
      orgId: "org-1",
    }),
    true,
  );
  assert.equal(
    canManageTarget(actor, {
      id: "peer",
      role: "superAdmin",
      orgId: "org-1",
    }),
    false,
  );
  assert.equal(
    canManageTargetAssignments(actor, {
      id: "other-org",
      role: "superAdmin",
      orgId: "org-2",
    }),
    false,
  );
  assert.equal(
    canManageTargetAssignments(actor, {
      id: "owner",
      role: "platformOwner",
      orgId: "org-1",
    }),
    false,
  );
});

test("normalizes string arrays for hub and team assignment inputs", () => {
  assert.deepEqual(normalizeStringArray([" a ", "a", "", 3, "b"]), ["a", "b"]);
  assert.deepEqual(normalizeStringArray(null), []);
});

test("structure updates preserve omitted optional fields and allow explicit clearing", () => {
  assert.deepEqual(
    nullableStringPatch({ name: "Wolves" }, ["logoUrl", "websiteUrl"], true),
    {},
  );
  assert.deepEqual(
    nullableStringPatch({ logoUrl: "  https://example.com/logo.png  " }, ["logoUrl"], true),
    { logoUrl: "https://example.com/logo.png" },
  );
  assert.deepEqual(
    nullableStringPatch({ logoUrl: null }, ["logoUrl"], true),
    { logoUrl: null },
  );
  assert.deepEqual(
    nullableStringPatch({}, ["logoUrl", "websiteUrl"], false),
    { logoUrl: null, websiteUrl: null },
  );
});

test("invitation expiration follows the same role hierarchy as creation", () => {
  assert.equal(canManageInvitationRole("platformOwner", "superAdmin"), true);
  assert.equal(canManageInvitationRole("superAdmin", "managerAdmin"), true);
  assert.equal(canManageInvitationRole("superAdmin", "staff"), true);
  assert.equal(canManageInvitationRole("superAdmin", "superAdmin"), false);
  assert.equal(canManageInvitationRole("superAdmin", "platformOwner"), false);
  assert.equal(canManageInvitationRole("superAdmin", "unknown"), false);
});

test("admin chat callables accept managed rooms but reject direct messages", () => {
  assert.equal(isManagedChatRoomType("league"), true);
  assert.equal(isManagedChatRoomType("event"), true);
  assert.equal(isManagedChatRoomType("direct"), false);
  assert.equal(isManagedChatRoomType(undefined), false);
});

test("team member records must all exist in the target organization", () => {
  const records = [
    { id: "u1", orgId: "org-1" },
    { id: "u2", orgId: "org-1" },
    { id: "external", orgId: "org-2" },
  ];
  assert.equal(teamMemberRecordsMatchOrg(["u1", "u2"], "org-1", records), true);
  assert.equal(teamMemberRecordsMatchOrg(["u1", "missing"], "org-1", records), false);
  assert.equal(teamMemberRecordsMatchOrg(["u1", "external"], "org-1", records), false);
});
