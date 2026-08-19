const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { after, before, test } = require("node:test");
const admin = require("firebase-admin");
const {
  buildTeamPlan,
  hubs,
  loadState,
  resolveLogoUrls,
  writeBackup,
  writeCanonicalStructure,
} = require("../scripts/reconcile-jphl-structure");

const PROJECT_ID = "jdb-league-hub";
const ORG_ID = "JMl7VkKm9tAADBaxxdiI";
const LEAGUE_ID = "KHuoFdO37RD0i2ARocIl";
const ISLAND_ID = "jphl_hub_island_hc";
const COWICHAN_ID = "jphl_hub_cowichan_jr_capitals";
const LEGACY_CAPITALS_ID = "jphl_team_319161";
const SCRIPT_PATH = path.resolve(__dirname, "../scripts/reconcile-jphl-structure.js");
let app;
let db;

function sourceTeam(team, hub) {
  return {
    orgId: ORG_ID,
    leagueId: LEAGUE_ID,
    hubId: hub.id,
    name: team.name,
    ageGroup: team.ageGroup,
    division: team.division,
    logoUrl: hub.logoSource,
    iconName: null,
    memberIds: [],
    sourceTeamId: team.sourceId,
    sourceDivisionId: "fixture",
    sourceUrl: "https://juniorprospectshockeyleague.com",
    createdAt: admin.firestore.Timestamp.fromMillis(1),
  };
}

async function seedProductionShape() {
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  await orgRef.set({ name: "JPHL", ownerId: "owner" });
  await leagueRef.set({
    orgId: ORG_ID,
    name: "Junior Prospects Hockey League",
  });

  const omittedHubs = new Set([
    "jphl_hub_bellingham_hc",
    COWICHAN_ID,
    "jphl_hub_velocity_ha",
  ]);
  for (const hub of hubs.filter((item) => !omittedHubs.has(item.id))) {
    const hubRef = leagueRef.collection("hubs").doc(hub.id);
    await hubRef.set({
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      name: hub.name,
      location: hub.location,
      logoUrl: hub.logoSource,
    });
    for (const team of hub.teams) {
      const data = sourceTeam(team, hub);
      if (team.sourceId === "398242") data.name = "18U AAA - EPIC HA";
      await hubRef.collection("teams").doc(`legacy_${team.sourceId}`).set(data);
    }
    await orgRef.collection("chatRooms").doc(`jphl_hub_room_${hub.slug.replaceAll("-", "_")}`).set({
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      hubId: hub.id,
      name: `${hub.name} - General`,
      type: "league",
      isArchived: false,
      participants: [],
      roomImageUrl: hub.logoSource,
    });
  }

  const islandHub = hubs.find((hub) => hub.id === ISLAND_ID);
  await leagueRef.collection("hubs").doc(ISLAND_ID).collection("teams")
    .doc(LEGACY_CAPITALS_ID).set({
      ...sourceTeam({
        name: "18U AAA - Junior Capitals",
        ageGroup: "18U",
        division: "AAA",
        sourceId: "319161",
      }, islandHub),
      memberIds: ["member"],
    });

  for (const [roomId, hubId] of [
    ["jphl_hub_room_lloydminster_athletics", "jphl_hub_lloydminster_athletics"],
    ["jphl_hub_room_south_sask_hc", "jphl_hub_south_sask_hc"],
  ]) {
    await orgRef.collection("chatRooms").doc(roomId).set({
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      hubId,
      name: "Retired room",
      type: "league",
      isArchived: false,
      participants: [],
    });
  }
  await orgRef.collection("chatRooms").doc("organization_general").set({
    orgId: ORG_ID,
    leagueId: null,
    hubId: null,
    name: "Organization General",
    type: "league",
    isArchived: false,
    participants: [],
  });

  await orgRef.collection("invitations").doc("invite").set({
    orgId: ORG_ID,
    hubIds: [ISLAND_ID, "jphl_hub_lloydminster_athletics"],
    teamIds: [LEGACY_CAPITALS_ID],
    status: "pending",
  });
}

before(async () => {
  assert(process.env.FIRESTORE_EMULATOR_HOST, "Firestore emulator is required");
  app = admin.initializeApp({ projectId: PROJECT_ID }, "jphl-structure-rules-test");
  db = admin.firestore(app);
  db.settings({ ignoreUndefinedProperties: true });
});

after(async () => {
  await db.recursiveDelete(db.collection("organizations").doc(ORG_ID));
  const userDocs = await db.collection("users").where("orgId", "==", ORG_ID).get();
  await Promise.all(userDocs.docs.map((doc) => doc.ref.delete()));
  await app.delete();
});

test("structure transaction archives stale rooms and guarded restore returns the exact prior shape", async () => {
  await db.recursiveDelete(db.collection("organizations").doc(ORG_ID));
  await seedProductionShape();
  let state = await loadState(db);
  let plan = buildTeamPlan(state.teamDocs
    .map((doc) => ({
      id: doc.id,
      hubId: doc.ref.parent.parent.id,
      name: doc.data().name,
      ageGroup: doc.data().ageGroup,
      sourceTeamId: doc.data().sourceTeamId,
      doc,
    })));
  assert.equal(plan.items.filter((item) => item.kind === "move").length, 1);
  assert.equal(state.retiredRooms.length, 2);

  await state.orgRef.collection("chatRooms").doc("concurrent_room").set({
    orgId: ORG_ID,
    leagueId: null,
    hubId: null,
    name: "Concurrent room",
    type: "league",
    isArchived: false,
  });
  await assert.rejects(
    writeCanonicalStructure(db, state, resolveLogoUrls(state), plan, "unwritten-backup.json"),
    /Production structure changed during validation.*concurrent_room/,
  );
  assert(!(await state.migrationRef.get()).exists);
  assert(!(await state.leagueRef.collection("hubs").doc("jphl_hub_bellingham_hc").get()).exists);

  state = await loadState(db);
  plan = buildTeamPlan(state.teamDocs.map((doc) => ({
    id: doc.id,
    hubId: doc.ref.parent.parent.id,
    name: doc.data().name,
    ageGroup: doc.data().ageGroup,
    sourceTeamId: doc.data().sourceTeamId,
    doc,
  })));

  const backupPath = writeBackup(state, plan);
  try {
    await writeCanonicalStructure(db, state, resolveLogoUrls(state), plan, backupPath);

    const orgRef = db.collection("organizations").doc(ORG_ID);
    const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
    const hubsAfter = await leagueRef.collection("hubs").get();
    const roomsAfter = await orgRef.collection("chatRooms").get();
    assert.equal(hubsAfter.size, 19);
    assert.equal(roomsAfter.docs.filter((doc) =>
      doc.data().hubId && doc.data().isArchived !== true).length, 19);
    assert(roomsAfter.docs
      .filter((doc) => doc.id.includes("lloydminster") || doc.id.includes("south_sask"))
      .every((doc) => doc.data().isArchived === true));
    assert(!(await leagueRef.collection("hubs").doc(ISLAND_ID).collection("teams")
      .doc(LEGACY_CAPITALS_ID).get()).exists);
    assert((await leagueRef.collection("hubs").doc(COWICHAN_ID).collection("teams")
      .doc(LEGACY_CAPITALS_ID).get()).exists);

    const newRoomMessage = orgRef.collection("chatRooms")
      .doc("jphl_hub_room_bellingham_hc").collection("messages").doc("new-message");
    await newRoomMessage.set({ text: "Do not orphan this message" });
    let rejectedRestore;
    try {
      execFileSync(process.execPath, [SCRIPT_PATH, "--restore", backupPath, "--apply"], {
        env: process.env,
        stdio: "pipe",
      });
    } catch (error) {
      rejectedRestore = error;
    }
    assert(rejectedRestore, "Restore should reject a message added to a newly created room");
    assert.match(rejectedRestore.stderr.toString(), /new-message/);
    await newRoomMessage.delete();

    execFileSync(process.execPath, [SCRIPT_PATH, "--restore", backupPath, "--apply"], {
      env: process.env,
      stdio: "pipe",
    });

    const restoredHubs = await leagueRef.collection("hubs").get();
    const restoredRooms = await orgRef.collection("chatRooms").get();
    assert.equal(restoredHubs.size, 16);
    assert.equal(restoredRooms.docs.filter((doc) =>
      doc.data().hubId && doc.data().isArchived !== true).length, 18);
    assert((await leagueRef.collection("hubs").doc(ISLAND_ID).collection("teams")
      .doc(LEGACY_CAPITALS_ID).get()).exists);
    assert(!(await leagueRef.collection("hubs").doc(COWICHAN_ID).get()).exists);
    assert(!(await orgRef.collection("auditLogs").doc("jphl-structure-2026-27").get()).exists);
  } finally {
    fs.rmSync(backupPath, { force: true });
  }
});
