const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { after, before, beforeEach, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  getDocs,
  collection,
  Timestamp,
  query,
  where,
  setDoc,
  serverTimestamp,
  updateDoc,
  writeBatch,
} = require("firebase/firestore");
const {
  ref,
  uploadBytes,
} = require("firebase/storage");

// Storage rules read Firestore documents through the emulator's configured
// project, so the test SDK must use the same demo project as firebase.rules-test.json.
const projectId = "demo-league-hub-rules";
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
    hasAcceptedCommunityGuidelines: true,
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
  const expiresAt = Timestamp.fromMillis(Date.now() + 60 * 60 * 1000);
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
    expiresAt,
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

test("expired and legacy pending invitations cannot be read or redeemed", async () => {
  const expiredInvite = {
    orgId: "org-1",
    email: "invitee@example.com",
    role: "staff",
    leagueIds: [],
    hubIds: [],
    teamIds: [],
    invitedBy: "admin",
    invitedByName: "Admin",
    createdAt: "2026-01-01T00:00:00.000Z",
    expiresAt: Timestamp.fromMillis(Date.now() - 60 * 1000),
    status: "pending",
    token: "expired-token",
  };
  const legacyInvite = {
    ...expiredInvite,
    email: "legacy@example.com",
    token: "legacy-token",
  };
  delete legacyInvite.expiresAt;
  await seedFirestore([
    ["organizations/org-1/invitations/expired", expiredInvite],
    ["organizations/org-1/invitations/legacy", legacyInvite],
    ["invitationLookups/expired-token", {
      token: "expired-token",
      orgId: "org-1",
      invitationId: "expired",
      email: "invitee@example.com",
      status: "pending",
      expiresAt: expiredInvite.expiresAt,
    }],
    ["invitationLookups/legacy-token", {
      token: "legacy-token",
      orgId: "org-1",
      invitationId: "legacy",
      email: "legacy@example.com",
      status: "pending",
    }],
  ]);

  const anonymousDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonymousDb, "invitationLookups/expired-token")));
  await assertFails(getDoc(doc(anonymousDb, "invitationLookups/legacy-token")));
  await assertFails(getDoc(doc(
    anonymousDb,
    "organizations/org-1/invitations/expired",
  )));

  const expiredDb = testEnv.authenticatedContext("expired-user", {
    email: "invitee@example.com",
  }).firestore();
  await assertFails(setDoc(doc(expiredDb, "users/expired-user"), user({
    id: "expired-user",
    email: "invitee@example.com",
    acceptedInvitationId: "expired",
  })));

  const legacyDb = testEnv.authenticatedContext("legacy-user", {
    email: "legacy@example.com",
  }).firestore();
  await assertFails(setDoc(doc(legacyDb, "users/legacy-user"), user({
    id: "legacy-user",
    email: "legacy@example.com",
    acceptedInvitationId: "legacy",
  })));
});

test("current mobile clients may create invites for server expiry stamping", async () => {
  await seedFirestore([
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
    })],
  ]);
  const db = testEnv.authenticatedContext("manager").firestore();
  const invitation = {
    orgId: "org-1",
    email: "invitee@example.com",
    role: "staff",
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: [],
    invitedBy: "manager",
    invitedByName: "Manager",
    createdAt: "2026-08-12T00:00:00.000Z",
    status: "pending",
    token: "mobile-token",
  };
  const batch = writeBatch(db);
  batch.set(
    doc(db, "organizations/org-1/invitations/mobile-invite"),
    invitation,
  );
  batch.set(doc(db, "invitationLookups/mobile-token"), {
    token: "mobile-token",
    orgId: "org-1",
    invitationId: "mobile-invite",
    email: "invitee@example.com",
    status: "pending",
    createdAt: invitation.createdAt,
  });
  await assertSucceeds(batch.commit());

  await assertFails(setDoc(
    doc(db, "organizations/org-1/invitations/too-long"),
    {
      ...invitation,
      token: "too-long-token",
      expiresAt: Timestamp.fromMillis(Date.now() + 8 * 24 * 60 * 60 * 1000),
    },
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

test("admins can update peer admin assignments but not role, status, or profile", async () => {
  await seedFirestore([
    ["users/admin", user({ id: "admin", role: "superAdmin" })],
    ["users/peer", user({ id: "peer", role: "superAdmin" })],
    ["users/owner", user({ id: "owner", role: "platformOwner" })],
  ]);
  const db = testEnv.authenticatedContext("admin").firestore();
  await assertSucceeds(updateDoc(doc(db, "users/peer"), {
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
  }));
  await assertFails(updateDoc(doc(db, "users/peer"), { role: "managerAdmin" }));
  await assertFails(updateDoc(doc(db, "users/peer"), { isActive: false }));
  await assertFails(updateDoc(doc(db, "users/peer"), { title: "Commissioner" }));
  await assertFails(updateDoc(doc(db, "users/owner"), {
    leagueIds: ["league-1"],
    hubIds: ["hub-1"],
    teamIds: ["team-1"],
  }));
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

test("manager can atomically add Staff to a team in another assigned hub", async () => {
  await seedFirestore([
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1", "hub-2"],
      teamIds: ["team-2"],
    })],
    ["users/staff", user({
      id: "staff",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
    })],
    ["organizations/org-1/leagues/league-1/hubs/hub-2/teams/team-2", {
      id: "team-2",
      orgId: "org-1",
      leagueId: "league-1",
      hubId: "hub-2",
      name: "Team 2",
      memberIds: [],
    }],
  ]);
  const db = testEnv.authenticatedContext("manager").firestore();
  const batch = writeBatch(db);
  batch.update(
    doc(db, "organizations/org-1/leagues/league-1/hubs/hub-2/teams/team-2"),
    { memberIds: ["staff"] },
  );
  batch.update(doc(db, "users/staff"), {
    leagueIds: ["league-1"],
    hubIds: ["hub-1", "hub-2"],
    teamIds: ["team-2"],
  });

  await assertSucceeds(batch.commit());
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

test("admin policy upload requires a reserved policy document", async () => {
  await seedFirestore([
    ["users/admin", user({id: "admin", role: "superAdmin"})],
    ["organizations/org-1/policies/reserved-policy", {
      id: "reserved-policy",
      orgId: "org-1",
      leagueId: null,
      hubId: null,
      teamId: null,
      uploadedBy: "admin",
      uploadedByName: "Admin",
      category: "Policy",
      fileUrl: "",
      fileType: "application/pdf",
      fileSize: 3,
      uploadStatus: "uploading",
      versions: [],
    }],
  ]);
  const storage = testEnv.authenticatedContext("admin").storage();

  await assertSucceeds(uploadBytes(
    ref(storage, "organizations/org-1/policies/reserved-policy/policy.pdf"),
    new Uint8Array([1, 2, 3]),
  ));
  await assertFails(uploadBytes(
    ref(storage, "organizations/org-1/policies/missing-policy/policy.pdf"),
    new Uint8Array([1, 2, 3]),
  ));
});

test("policy writes allow organization, hub, and team targets but reject league-only scope", async () => {
  await seedFirestore([
    ["users/owner", user({id: "owner", role: "platformOwner", orgId: null})],
    ["users/admin", user({id: "admin", role: "superAdmin"})],
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
      teamIds: ["team-1"],
    })],
    ["users/staff", user({id: "staff"})],
    ["organizations/org-1/leagues/league-1", {
      id: "league-1",
      orgId: "org-1",
      name: "League",
    }],
    ["organizations/org-1/leagues/league-1/hubs/hub-1", {
      id: "hub-1",
      orgId: "org-1",
      leagueId: "league-1",
      name: "Hub",
    }],
    ["organizations/org-1/leagues/league-1/hubs/hub-1/teams/team-1", {
      id: "team-1",
      orgId: "org-1",
      leagueId: "league-1",
      hubId: "hub-1",
      name: "Team",
    }],
  ]);
  const policy = (id, uploadedBy, target) => ({
    id,
    orgId: "org-1",
    name: id,
    category: "Policy",
    uploadedBy,
    uploadedByName: uploadedBy,
    fileUrl: "",
    fileType: "pdf",
    fileSize: 10,
    versions: [],
    createdAt: "2026-01-01T00:00:00.000Z",
    ...target,
  });
  const adminDb = testEnv.authenticatedContext("admin").firestore();
  const ownerDb = testEnv.authenticatedContext("owner").firestore();
  const managerDb = testEnv.authenticatedContext("manager").firestore();
  const staffDb = testEnv.authenticatedContext("staff").firestore();

  await assertSucceeds(setDoc(
    doc(adminDb, "organizations/org-1/policies/org-wide"),
    policy("org-wide", "admin", {leagueId: null, hubId: null, teamId: null}),
  ));
  await assertSucceeds(setDoc(
    doc(adminDb, "organizations/org-1/policies/waiver"),
    {
      ...policy("waiver", "admin", {leagueId: null, hubId: null, teamId: null}),
      category: "Waiver",
    },
  ));
  await assertSucceeds(setDoc(
    doc(ownerDb, "organizations/org-1/policies/owner-org-wide"),
    policy("owner-org-wide", "owner", {leagueId: null, hubId: null, teamId: null}),
  ));
  await assertFails(setDoc(
    doc(ownerDb, "organizations/org-1/policies/owner-league-only"),
    policy("owner-league-only", "owner", {leagueId: "league-1", hubId: null, teamId: null}),
  ));
  await assertFails(setDoc(
    doc(managerDb, "organizations/org-1/policies/manager-org-wide"),
    policy("manager-org-wide", "manager", {leagueId: null, hubId: null, teamId: null}),
  ));
  await assertFails(setDoc(
    doc(managerDb, "organizations/org-1/policies/league-only"),
    policy("league-only", "manager", {leagueId: "league-1", hubId: null, teamId: null}),
  ));
  await assertSucceeds(setDoc(
    doc(managerDb, "organizations/org-1/policies/hub"),
    policy("hub", "manager", {leagueId: "league-1", hubId: "hub-1", teamId: null}),
  ));
  await assertSucceeds(setDoc(
    doc(managerDb, "organizations/org-1/policies/team"),
    policy("team", "manager", {leagueId: "league-1", hubId: "hub-1", teamId: "team-1"}),
  ));
  await assertSucceeds(updateDoc(
    doc(ownerDb, "organizations/org-1/policies/owner-org-wide"),
    {category: "Waiver"},
  ));
  await assertSucceeds(updateDoc(
    doc(adminDb, "organizations/org-1/policies/org-wide"),
    {category: "Waiver"},
  ));
  await assertSucceeds(updateDoc(
    doc(managerDb, "organizations/org-1/policies/hub"),
    {category: "Waiver"},
  ));
  await assertFails(updateDoc(
    doc(staffDb, "organizations/org-1/policies/org-wide"),
    {category: "Waiver"},
  ));
  await assertFails(setDoc(
    doc(staffDb, "organizations/org-1/policies/staff-policy"),
    policy("staff-policy", "staff", {leagueId: null, hubId: null, teamId: null}),
  ));
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

test("users can manage only their own chat safety settings", async () => {
  await seedFirestore([
    ["users/member", user({
      id: "member",
      hasAcceptedCommunityGuidelines: false,
    })],
    ["users/other", user({ id: "other" })],
  ]);
  const db = testEnv.authenticatedContext("member").firestore();

  await assertSucceeds(updateDoc(doc(db, "users/member"), {
    blockedUserIds: ["other"],
    hasAcceptedCommunityGuidelines: true,
  }));
  await assertFails(updateDoc(doc(db, "users/member"), {
    hasAcceptedCommunityGuidelines: false,
  }));
  await assertFails(updateDoc(doc(db, "users/member"), {
    blockedUserIds: ["member"],
  }));
  await assertFails(updateDoc(doc(db, "users/other"), {
    blockedUserIds: ["member"],
  }));
});

test("message reports must reference a readable real message", async () => {
  const room = {
    id: "room-1",
    orgId: "org-1",
    type: "league",
    participants: ["member", "other"],
    name: "Team room",
  };
  const message = {
    chatRoomId: "room-1",
    senderId: "other",
    senderName: "Other",
    text: "Message",
    createdAt: "2026-01-01T00:00:00.000Z",
    readBy: ["other"],
  };
  await seedFirestore([
    ["users/member", user({ id: "member" })],
    ["users/other", user({ id: "other" })],
    ["organizations/org-1/chatRooms/room-1", room],
    ["organizations/org-1/chatRooms/room-1/messages/message-1", message],
  ]);
  const db = testEnv.authenticatedContext("member").firestore();
  const baseReport = {
    orgId: "org-1",
    roomId: "room-1",
    messageId: "message-1",
    reporterId: "member",
    reportedUserId: "other",
    reason: "Harassment or bullying",
    status: "open",
    createdAt: serverTimestamp(),
  };

  await assertSucceeds(setDoc(
    doc(db, "organizations/org-1/messageReports/report-1"),
    baseReport,
  ));
  await assertFails(setDoc(
    doc(db, "organizations/org-1/messageReports/report-2"),
    { ...baseReport, messageId: "missing" },
  ));
  await assertFails(setDoc(
    doc(db, "organizations/org-1/messageReports/report-3"),
    { ...baseReport, reportedUserId: "forged" },
  ));
});

test("direct room messages remain private when admins can inspect room metadata", async () => {
  const dm = {
    id: "dm-1",
    orgId: "org-1",
    type: "direct",
    participants: ["member", "peer"],
    participantNames: {member: "Member", peer: "Peer"},
    name: "Member & Peer",
    isArchived: false,
    lastMessage: "Private preview",
  };
  await seedFirestore([
    ["users/member", user({id: "member", displayName: "Member"})],
    ["users/peer", user({id: "peer", displayName: "Peer"})],
    ["users/outsider", user({id: "outsider", displayName: "Outsider"})],
    ["users/admin", user({
      id: "admin",
      displayName: "Admin",
      role: "superAdmin",
    })],
    ["organizations/org-1/chatRooms/dm-1", dm],
    ["organizations/org-1/chatRooms/dm-1/messages/message-1", {
      chatRoomId: "dm-1",
      senderId: "member",
      senderName: "Member",
      text: "Private message",
      previewText: "Private message",
      createdAt: "2026-01-01T00:00:00.000Z",
      readBy: ["member"],
    }],
  ]);

  const participantDb = testEnv.authenticatedContext("member").firestore();
  const outsiderDb = testEnv.authenticatedContext("outsider").firestore();
  const adminDb = testEnv.authenticatedContext("admin").firestore();
  await assertSucceeds(getDoc(doc(
    participantDb,
    "organizations/org-1/chatRooms/dm-1",
  )));
  await assertFails(getDoc(doc(
    outsiderDb,
    "organizations/org-1/chatRooms/dm-1",
  )));
  await assertSucceeds(getDoc(doc(
    adminDb,
    "organizations/org-1/chatRooms/dm-1",
  )));
  await assertSucceeds(getDoc(doc(
    participantDb,
    "organizations/org-1/chatRooms/dm-1/messages/message-1",
  )));
  await assertFails(getDoc(doc(
    adminDb,
    "organizations/org-1/chatRooms/dm-1/messages/message-1",
  )));
  await assertSucceeds(getDocs(query(
    collection(participantDb, "organizations/org-1/chatRooms"),
    where("orgId", "==", "org-1"),
    where("type", "==", "direct"),
    where("isArchived", "==", false),
    where("participants", "array-contains", "member"),
  )));
  await assertFails(getDocs(query(
    collection(outsiderDb, "organizations/org-1/chatRooms"),
    where("orgId", "==", "org-1"),
    where("type", "==", "direct"),
    where("isArchived", "==", false),
  )));
});

test("staff can send constrained messages only to readable rooms", async () => {
  const leagueRoom = {
    id: "league-room",
    orgId: "org-1",
    type: "league",
    leagueId: "league-1",
    hubId: null,
    teamId: null,
    participants: [],
    name: "League room",
    isArchived: false,
  };
  const directRoom = {
    id: "direct-room",
    orgId: "org-1",
    type: "direct",
    participants: ["member", "peer"],
    name: "Member & Peer",
    isArchived: false,
  };
  await seedFirestore([
    ["users/member", user({
      id: "member",
      displayName: "Member",
      leagueIds: ["league-1"],
      blockedUserIds: [],
    })],
    ["users/peer", user({
      id: "peer",
      displayName: "Peer",
      leagueIds: ["league-1"],
      blockedUserIds: [],
    })],
    ["users/outsider", user({id: "outsider", displayName: "Outsider"})],
    ["organizations/org-1/chatRooms/league-room", leagueRoom],
    ["organizations/org-1/chatRooms/direct-room", directRoom],
  ]);
  const memberDb = testEnv.authenticatedContext("member").firestore();
  const peerDb = testEnv.authenticatedContext("peer").firestore();
  const validMessage = (roomId, senderId, senderName, text = "Hello") => ({
    chatRoomId: roomId,
    senderId,
    senderName,
    text,
    previewText: text,
    createdAt: serverTimestamp(),
    readBy: [senderId],
  });

  await assertSucceeds(setDoc(doc(
    memberDb,
    "organizations/org-1/chatRooms/league-room/messages/message-1",
  ), validMessage("league-room", "member", "Member")));
  await assertSucceeds(setDoc(doc(
    memberDb,
    "organizations/org-1/chatRooms/direct-room/messages/message-1",
  ), validMessage("direct-room", "member", "Member")));
  await assertSucceeds(setDoc(doc(
    peerDb,
    "organizations/org-1/chatRooms/direct-room/messages/message-2",
  ), validMessage("direct-room", "peer", "Peer")));
  await assertFails(setDoc(doc(
    memberDb,
    "organizations/org-1/chatRooms/direct-room/messages/forged",
  ), {
    ...validMessage("direct-room", "member", "Member"),
    previewText: "Different private preview",
  }));
  await assertFails(setDoc(doc(
    memberDb,
    "organizations/org-1/chatRooms/direct-room/messages/oversized",
  ), validMessage("direct-room", "member", "Member", "x".repeat(4001))));

  await updateDoc(doc(peerDb, "users/peer"), {blockedUserIds: ["member"]});
  await assertFails(setDoc(doc(
    memberDb,
    "organizations/org-1/chatRooms/direct-room/messages/blocked",
  ), validMessage("direct-room", "member", "Member")));
});

test("shared-room posting follows platform owner, admin, manager, and staff scope", async () => {
  const hubRoom = {
    id: "hub-room",
    orgId: "org-1",
    type: "league",
    leagueId: "league-1",
    hubId: "hub-1",
    teamId: null,
    participants: [],
    name: "Hub - General",
    isArchived: false,
  };
  const teamRoom = {
    ...hubRoom,
    id: "team-room",
    teamId: "team-1",
    name: "Team - General",
  };
  const actors = [
    user({id: "owner", displayName: "Owner", role: "platformOwner", orgId: null}),
    user({id: "admin", displayName: "Admin", role: "superAdmin"}),
    user({id: "manager", displayName: "Manager", role: "managerAdmin", hubIds: ["hub-1"]}),
    user({id: "staff", displayName: "Staff", teamIds: ["team-1"]}),
    user({id: "outsider", displayName: "Outsider"}),
  ];
  await seedFirestore([
    ...actors.map((actor) => [`users/${actor.id}`, actor]),
    ["organizations/org-1/chatRooms/hub-room", hubRoom],
    ["organizations/org-1/chatRooms/team-room", teamRoom],
  ]);

  const post = (actor, roomId) => setDoc(doc(
    testEnv.authenticatedContext(actor.id).firestore(),
    `organizations/org-1/chatRooms/${roomId}/messages/${actor.id}`,
  ), {
    chatRoomId: roomId,
    senderId: actor.id,
    senderName: actor.displayName,
    text: "Hello",
    previewText: "Hello",
    createdAt: serverTimestamp(),
    readBy: [actor.id],
  });

  await assertSucceeds(post(actors[0], "hub-room"));
  await assertSucceeds(post(actors[1], "hub-room"));
  await assertSucceeds(post(actors[2], "hub-room"));
  await assertSucceeds(post(actors[3], "team-room"));
  await assertFails(post(actors[4], "hub-room"));
});

test("posting requires accepted community guidelines", async () => {
  await seedFirestore([
    ["users/member", user({
      id: "member",
      displayName: "Member",
      leagueIds: ["league-1"],
      hasAcceptedCommunityGuidelines: false,
    })],
    ["organizations/org-1/chatRooms/league-room", {
      id: "league-room",
      orgId: "org-1",
      type: "league",
      leagueId: "league-1",
      hubId: null,
      teamId: null,
      participants: [],
      name: "League room",
      isArchived: false,
    }],
  ]);
  const db = testEnv.authenticatedContext("member").firestore();
  const messageRef = doc(
    db,
    "organizations/org-1/chatRooms/league-room/messages/message-1",
  );
  const message = {
    chatRoomId: "league-room",
    senderId: "member",
    senderName: "Member",
    text: "Hello",
    previewText: "Hello",
    createdAt: serverTimestamp(),
    readBy: ["member"],
  };

  await assertFails(setDoc(messageRef, message));
  await assertSucceeds(updateDoc(doc(db, "users/member"), {
    hasAcceptedCommunityGuidelines: true,
  }));
  await assertSucceeds(setDoc(messageRef, message));
});

test("malformed team rooms cannot fall through to league visibility", async () => {
  await seedFirestore([
    ["users/member", user({
      id: "member",
      displayName: "Member",
      leagueIds: ["league-1"],
      teamIds: [],
    })],
    ["organizations/org-1/chatRooms/malformed", {
      id: "malformed",
      orgId: "org-1",
      type: "league",
      leagueId: "league-1",
      hubId: null,
      teamId: "private-team",
      participants: [],
      name: "Private team room",
      isArchived: false,
      lastMessage: "Private",
    }],
  ]);
  const db = testEnv.authenticatedContext("member").firestore();
  await assertFails(getDoc(doc(
    db,
    "organizations/org-1/chatRooms/malformed",
  )));
});

test("scoped room list query shapes return only readable metadata", async () => {
  const room = (id, overrides) => ({
    id,
    orgId: "org-1",
    type: "league",
    leagueId: null,
    hubId: null,
    teamId: null,
    participants: [],
    name: id,
    isArchived: false,
    ...overrides,
  });
  await seedFirestore([
    ["users/member", user({
      id: "member",
      displayName: "Member",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
      teamIds: ["team-1"],
    })],
    ["organizations/org-1/chatRooms/unscoped", room("unscoped", {})],
    ["organizations/org-1/chatRooms/league", room("league", {
      leagueId: "league-1",
    })],
    ["organizations/org-1/chatRooms/hub", room("hub", {
      leagueId: "league-1",
      hubId: "hub-1",
    })],
    ["organizations/org-1/chatRooms/team", room("team", {
      leagueId: "league-1",
      hubId: "hub-1",
      teamId: "team-1",
    })],
    ["organizations/org-1/chatRooms/private", room("private", {
      leagueId: "league-2",
      hubId: "hub-2",
      teamId: "team-2",
    })],
  ]);
  const rooms = collection(
    testEnv.authenticatedContext("member").firestore(),
    "organizations/org-1/chatRooms",
  );
  const base = [
    where("orgId", "==", "org-1"),
    where("isArchived", "==", false),
    where("type", "in", ["league", "event"]),
  ];
  const snapshots = await Promise.all([
    assertSucceeds(getDocs(query(
      rooms,
      ...base,
      where("hubId", "==", null),
      where("teamId", "==", null),
      where("leagueId", "==", null),
    ))),
    assertSucceeds(getDocs(query(
      rooms,
      ...base,
      where("hubId", "==", null),
      where("teamId", "==", null),
      where("leagueId", "in", ["league-1"]),
    ))),
    assertSucceeds(getDocs(query(
      rooms,
      ...base,
      where("hubId", "in", ["hub-1"]),
    ))),
    assertSucceeds(getDocs(query(
      rooms,
      ...base,
      where("teamId", "in", ["team-1"]),
    ))),
  ]);
  assert.deepEqual(
    snapshots.map((snapshot) => snapshot.docs.map((item) => item.id)),
    [["unscoped"], ["league"], ["hub", "team"], ["team"]],
  );
  await assertFails(getDocs(query(
    rooms,
    ...base,
    where("hubId", "in", ["hub-2"]),
  )));
});

test("Structure-managed General room identity is server-owned", async () => {
  const generalRoom = {
    id: "hub-general",
    orgId: "org-1",
    type: "league",
    leagueId: "league-1",
    hubId: "hub-1",
    teamId: null,
    participants: [],
    name: "Calgary - General",
    roomIconName: "hub",
    roomImageUrl: "https://example.com/calgary.png",
    isArchived: false,
  };
  await seedFirestore([
    ["organizations/org-1", { id: "org-1", ownerId: "owner" }],
    ["organizations/org-1/leagues/league-1", { id: "league-1", orgId: "org-1" }],
    ["organizations/org-1/leagues/league-1/hubs/hub-1", {
      id: "hub-1",
      orgId: "org-1",
      leagueId: "league-1",
      name: "Calgary",
      logoUrl: "https://example.com/calgary.png",
      iconName: null,
    }],
    ["organizations/org-1/chatRooms/hub-general", generalRoom],
    ["organizations/org-1/chatRooms/event-room", {
      ...generalRoom,
      id: "event-room",
      type: "event",
      name: "Hub event",
    }],
    ["users/owner", user({ id: "owner", role: "platformOwner" })],
    ["users/admin", user({ id: "admin", role: "superAdmin" })],
    ["users/manager", user({
      id: "manager",
      role: "managerAdmin",
      leagueIds: ["league-1"],
      hubIds: ["hub-1"],
    })],
    ["users/staff", user({ id: "staff", role: "staff" })],
  ]);

  for (const userId of ["owner", "admin", "manager", "staff"]) {
    const userDb = testEnv.authenticatedContext(userId).firestore();
    const roomRef = doc(
      userDb,
      "organizations/org-1/chatRooms/hub-general",
    );
    await assertFails(updateDoc(roomRef, { name: "Drifted name" }));
    await assertFails(updateDoc(roomRef, { roomImageUrl: null }));
    await assertFails(setDoc(
      doc(userDb, `organizations/org-1/chatRooms/forged-${userId}`),
      { ...generalRoom, id: `forged-${userId}` },
    ));
  }

  const managerRoom = doc(
    testEnv.authenticatedContext("manager").firestore(),
    "organizations/org-1/chatRooms/hub-general",
  );
  await assertSucceeds(updateDoc(managerRoom, { isArchived: true }));
  await assertFails(updateDoc(managerRoom, {
    type: "event",
    name: "Detached event",
    hubId: null,
  }));
  await assertFails(updateDoc(
    doc(
      testEnv.authenticatedContext("manager").firestore(),
      "organizations/org-1/chatRooms/event-room",
    ),
    { type: "league" },
  ));

  const groupRoomRef = doc(
    testEnv.authenticatedContext("manager").firestore(),
    "organizations/org-1/chatRooms/group-room",
  );
  await assertSucceeds(setDoc(groupRoomRef, {
    ...generalRoom,
    id: "group-room",
    type: "event",
    roomPurpose: "group",
    name: "Hub Leadership",
  }));
  await assertFails(setDoc(
    doc(
      testEnv.authenticatedContext("manager").firestore(),
      "organizations/org-1/chatRooms/invalid-purpose",
    ),
    {
      ...generalRoom,
      id: "invalid-purpose",
      type: "event",
      roomPurpose: "private",
      name: "Invalid purpose",
    },
  ));
  await assertFails(setDoc(
    doc(
      testEnv.authenticatedContext("manager").firestore(),
      "organizations/org-1/chatRooms/invalid-purpose-type",
    ),
    {
      ...generalRoom,
      id: "invalid-purpose-type",
      type: "league",
      roomPurpose: "group",
      name: "Invalid purpose type",
    },
  ));
  await assertFails(updateDoc(groupRoomRef, { roomPurpose: "event" }));

  const legacyRoom = {
    orgId: "org-1",
    name: "Calgary – General",
    type: "league",
    leagueId: "league-1",
    hubId: "hub-1",
    teamId: null,
    participants: [],
    isArchived: false,
    createdAt: serverTimestamp(),
    lastMessage: null,
    lastMessageAt: serverTimestamp(),
    lastMessageBy: null,
    roomIconName: null,
    roomImageUrl: "https://example.com/calgary.png",
  };
  await assertSucceeds(setDoc(
    doc(
      testEnv.authenticatedContext("manager").firestore(),
      "organizations/org-1/chatRooms/legacy-hub-room",
    ),
    legacyRoom,
  ));
  await assertFails(setDoc(
    doc(
      testEnv.authenticatedContext("manager").firestore(),
      "organizations/org-1/chatRooms/forged-legacy-hub-room",
    ),
    { ...legacyRoom, name: "Wrong name – General" },
  ));
});
