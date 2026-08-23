const assert = require("node:assert/strict");
const test = require("node:test");
const {
  assignableRoles,
  buildChatRoomSetupPlan,
  canAccessOrg,
  canCreateLeague,
  canManageInvitationRole,
  canManageTarget,
  canManageTargetAssignments,
  chatRoomSetupPreviewToken,
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
  assert.equal(canAccessOrg({ id: "staff", role: "staff", orgId: "org-1", isActive: true }, "org-1"), false);
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
  for (const category of ["Policy", "Waiver", "Protocol", "Code of Conduct", "Other"]) {
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

test("chat room setup plans only missing hub and team rooms", () => {
  const plan = buildChatRoomSetupPlan({
    hubs: [
      { id: "h1", leagueId: "l1", name: "Calgary", logoUrl: "hub.png" },
      { id: "h2", leagueId: "l1", name: "Red Deer" },
    ],
    teams: [
      { id: "t1", leagueId: "l1", hubId: "h1", name: "Calgary U18", logoUrl: "team.png" },
      { id: "t2", leagueId: "l1", hubId: "h2", name: "Red Deer U18" },
    ],
    rooms: [
      { id: "hub-active", type: "league", leagueId: "l1", hubId: "h1", teamId: null, isArchived: false },
      { id: "team-archived", type: "event", leagueId: "l1", hubId: "h2", teamId: "t2", isArchived: true },
      { id: "direct", type: "direct", leagueId: "l1", hubId: "h1", teamId: "t1", isArchived: false },
    ],
  });

  assert.equal(plan.totalHubs, 2);
  assert.equal(plan.totalTeams, 2);
  assert.equal(plan.coveredHubs, 1);
  assert.equal(plan.coveredTeams, 0);
  assert.equal(plan.createCount, 2);
  assert.equal(plan.restoreCount, 1);
  assert.deepEqual(plan.targets.map((target) => ({
    key: target.key,
    action: target.action,
    name: target.name,
    image: target.roomImageUrl,
  })), [
    { key: "hub:l1:h2", action: "create", name: "Red Deer - General", image: null },
    { key: "team:l1:h1:t1", action: "create", name: "Calgary U18 - General", image: "team.png" },
    { key: "team:l1:h2:t2", action: "restore", name: "Red Deer U18 - General", image: null },
  ]);
});

test("chat room setup treats an active scoped room as covered regardless of legacy name", () => {
  const plan = buildChatRoomSetupPlan({
    hubs: [{ id: "h1", leagueId: "l1", name: "Calgary" }],
    teams: [{ id: "t1", leagueId: "l1", hubId: "h1", name: "Calgary U18" }],
    rooms: [
      { id: "legacy-hub", type: "event", leagueId: "l1", hubId: "h1", teamId: null, isArchived: false },
      { id: "legacy-team", type: "league", leagueId: "l1", hubId: "h1", teamId: "t1", isArchived: false },
    ],
  });

  assert.equal(plan.coveredHubs, 1);
  assert.equal(plan.coveredTeams, 1);
  assert.deepEqual(plan.targets, []);
});

test("chat room setup preview tokens change when an exact planned action changes", () => {
  const basePlan = buildChatRoomSetupPlan({
    hubs: [{ id: "h1", leagueId: "l1", name: "Calgary" }],
    teams: [],
    rooms: [],
  });
  const restoredPlan = buildChatRoomSetupPlan({
    hubs: [{ id: "h1", leagueId: "l1", name: "Calgary" }],
    teams: [],
    rooms: [
      { id: "archived", type: "league", leagueId: "l1", hubId: "h1", teamId: null, isArchived: true },
    ],
  });

  assert.notEqual(chatRoomSetupPreviewToken(basePlan), chatRoomSetupPreviewToken(restoredPlan));
  assert.equal(chatRoomSetupPreviewToken(basePlan), chatRoomSetupPreviewToken({
    ...basePlan,
    targets: [...basePlan.targets].reverse(),
  }));
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
