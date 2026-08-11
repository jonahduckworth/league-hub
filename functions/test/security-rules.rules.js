const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {
  ref,
  uploadBytes,
} = require("firebase/storage");

const projectId = `league-hub-rules-${process.pid}`;
let testEnv;

function emulatorAddress(name, fallbackPort) {
  const value = process.env[name] ?? `127.0.0.1:${fallbackPort}`;
  const [host, port] = value.split(":");
  return { host, port: Number(port) };
}

function user(overrides = {}) {
  return {
    id: "user",
    email: "user@example.com",
    displayName: "User",
    role: "staff",
    orgId: "org-1",
    leagueIds: [],
    hubIds: [],
    teamIds: [],
    createdAt: "2026-01-01T00:00:00.000Z",
    isActive: true,
    ...overrides,
  };
}

async function seedFirestore(entries) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(entries.map(([documentPath, data]) =>
      setDoc(doc(db, documentPath), data)));
  });
}

before(async () => {
  const root = path.resolve(__dirname, "../..");
  const firestore = emulatorAddress("FIRESTORE_EMULATOR_HOST", 8080);
  const storage = emulatorAddress("FIREBASE_STORAGE_EMULATOR_HOST", 9199);
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      ...firestore,
      rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8"),
    },
    storage: {
      ...storage,
      rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

test("invitation acceptance rejects forged league assignments", async () => {
  const invite = {
    orgId: "org-1",
    email: "invitee@example.com",
    role: "staff",
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
    invitedBy: "admin",
    invitedByName: "Admin",
    createdAt: "2026-01-01T00:00:00.000Z",
    status: "pending",
    token: "token",
  };
  await seedFirestore([
    ["organizations/org-1/invitations/invite-1", invite],
  ]);

  const context = testEnv.authenticatedContext("invitee", {
    email: "invitee@example.com",
  });
  const requestedUser = user({
    id: "invitee",
    email: "invitee@example.com",
    acceptedInvitationId: "invite-1",
    leagueIds: ["league-1", "forged-league"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
  });

  await assertFails(setDoc(doc(context.firestore(), "users/invitee"), requestedUser));
  await assertSucceeds(setDoc(
    doc(context.firestore(), "users/invitee"),
    { ...requestedUser, leagueIds: ["league-1"] },
  ));
});

test("admin cannot move a managed user into another organization", async () => {
  await seedFirestore([
    ["users/admin", user({ id: "admin", role: "superAdmin" })],
    ["users/staff", user({ id: "staff" })],
  ]);
  const db = testEnv.authenticatedContext("admin").firestore();
  await assertFails(updateDoc(doc(db, "users/staff"), { orgId: "org-2" }));
  await assertSucceeds(updateDoc(doc(db, "users/staff"), { title: "Coach" }));
});

test("admin cannot replace organization owner and bootstrap a platform owner", async () => {
  const organization = {
    id: "org-1",
    name: "League Hub",
    ownerId: "owner",
    createdAt: "2026-01-01T00:00:00.000Z",
  };
  await seedFirestore([
    ["organizations/org-1", organization],
    ["users/admin", user({ id: "admin", role: "superAdmin" })],
  ]);
  const adminDb = testEnv.authenticatedContext("admin").firestore();
  await assertFails(updateDoc(doc(adminDb, "organizations/org-1"), {
    ownerId: "attacker",
  }));

  const attackerDb = testEnv.authenticatedContext("attacker", {
    email: "attacker@example.com",
  }).firestore();
  await assertFails(setDoc(doc(attackerDb, "users/attacker"), user({
    id: "attacker",
    email: "attacker@example.com",
    role: "platformOwner",
  })));
});

test("manager cannot change the roster of an unassigned team", async () => {
  await seedFirestore([
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
    })],
    ["organizations/org-1/leagues/league-1/hubs/hub-1/teams/team-1", {
      id: "team-1",
      orgId: "org-1",
      leagueId: "league-1",
      hubId: "hub-1",
      name: "Team",
      memberIds: [],
    }],
  ]);
  const db = testEnv.authenticatedContext("manager").firestore();
  const teamRef = doc(db,
    "organizations/org-1/leagues/league-1/hubs/hub-1/teams/team-1");
  await assertFails(updateDoc(teamRef, { memberIds: ["staff"] }));
  await assertSucceeds(updateDoc(teamRef, { name: "Renamed Team" }));
});

test("manager cannot pin an announcement through a direct update", async () => {
  await seedFirestore([
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
    })],
    ["organizations/org-1/leagues/league-1", {
      id: "league-1",
      orgId: "org-1",
      name: "League",
    }],
    ["organizations/org-1/announcements/announcement-1", {
      id: "announcement-1",
      orgId: "org-1",
      scope: "league",
      leagueId: "league-1",
      hubId: null,
      teamId: null,
      title: "Update",
      body: "Body",
      authorId: "manager",
      authorName: "Manager",
      authorRole: "Manager",
      attachments: [],
      isPinned: false,
      createdAt: "2026-01-01T00:00:00.000Z",
    }],
  ]);
  const db = testEnv.authenticatedContext("manager").firestore();
  const announcementRef = doc(db,
    "organizations/org-1/announcements/announcement-1");
  await assertFails(updateDoc(announcementRef, { isPinned: true }));
  await assertSucceeds(updateDoc(announcementRef, { title: "Edited" }));
});

test("manager cannot overwrite another manager's out-of-scope policy file", async () => {
  await seedFirestore([
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
    })],
    ["organizations/org-1/policies/policy-1", {
      id: "policy-1",
      orgId: "org-1",
      leagueId: "league-1",
      hubId: "hub-2",
      teamId: null,
      uploadedBy: "other-manager",
      category: "Policy",
    }],
  ]);
  const objectPath = "organizations/org-1/policies/policy-1/policy.pdf";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), objectPath), new Uint8Array([1]));
  });

  const storage = testEnv.authenticatedContext("manager").storage();
  await assertFails(uploadBytes(ref(storage, objectPath), new Uint8Array([2])));
});

test("admin cannot mutate a direct-message room as managed content", async () => {
  await seedFirestore([
    ["users/admin", user({ id: "admin", role: "superAdmin" })],
    ["organizations/org-1/chatRooms/dm-1", {
      id: "dm-1",
      orgId: "org-1",
      type: "direct",
      participants: ["member-1", "member-2"],
      name: "Direct message",
    }],
  ]);
  const db = testEnv.authenticatedContext("admin").firestore();
  await assertFails(updateDoc(
    doc(db, "organizations/org-1/chatRooms/dm-1"),
    { name: "Admin renamed" },
  ));
});
