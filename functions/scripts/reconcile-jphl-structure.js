#!/usr/bin/env node

/*
 * Reconciles the production JPHL structure with the official JPHL directory.
 *
 * Safety defaults:
 *   node scripts/reconcile-jphl-structure.js          # validate and dry-run
 *   node scripts/reconcile-jphl-structure.js --apply  # back up, then mutate
 */

const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

const PROJECT_ID = "jdb-league-hub";
const STORAGE_BUCKET = "jdb-league-hub.firebasestorage.app";
const ORG_ID = "JMl7VkKm9tAADBaxxdiI";
const LEAGUE_ID = "KHuoFdO37RD0i2ARocIl";
const DIRECTORY_URL = "https://juniorprospectshockeyleague.com";
const CURRENT_SEASON_ID = "14553";
const LEGACY_SEASON_ID = "12322";
const RAMP_DIVISION_IDS = {
  "14U": "16624",
  "15U": "16623",
  "17U": "23859",
  "18U": "16622",
};
const APPLY = process.argv.includes("--apply");
const UNKNOWN_ARGS = process.argv.slice(2).filter((arg) => arg !== "--apply");

if (UNKNOWN_ARGS.length > 0) {
  throw new Error(`Unknown arguments: ${UNKNOWN_ARGS.join(", ")}`);
}

const hubs = [
  {
    slug: "bellingham-hc",
    name: "Bellingham HC",
    location: "Bellingham, WA",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Bellingham HC Logo - White.png",
    teams: [["398224", "17U"]],
  },
  {
    slug: "bow-valley-hc",
    name: "Bow Valley HC",
    location: "Cochrane, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Bow%20Valley%20Circle%20Badge.png",
    teams: [["398202", "14U"], ["398214", "15U"], ["398225", "17U"], ["398237", "18U"]],
  },
  {
    slug: "calgary-rockies",
    name: "Calgary Rockies",
    location: "Calgary, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Calgary%20Rockies.png",
    teams: [["398203", "14U"], ["398215", "15U"], ["398226", "17U"], ["398238", "18U"]],
  },
  {
    slug: "calgary-stallions",
    name: "Calgary Stallions",
    location: "Calgary, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Calgary%20Stallions.png",
    teams: [["398239", "18U"]],
  },
  {
    slug: "coquitlam-hc",
    name: "Coquitlam HC",
    location: "Coquitlam, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Coquitlam%20HC%20PNG.png",
    teams: [["398204", "14U"], ["398216", "15U"], ["398227", "17U"], ["398240", "18U"]],
  },
  {
    slug: "cowichan-jr-capitals",
    name: "Cowichan Jr Capitals",
    location: "Cowichan Valley, BC",
    logoSource: "https://cloud.rampinteractive.com/juniorprospectshockeyleague/files/JR-CAPITALS-Logo.png",
    teams: [["398241", "18U"]],
  },
  {
    slug: "epic-hockey-academy",
    name: "Epic Hockey Academy",
    location: "Middlesex, ON",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/EPIC-E-icon-full-colour-no-background.png",
    teams: [["398242", "18U"]],
  },
  {
    slug: "hc-edmonton",
    name: "HC Edmonton",
    location: "Edmonton, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/EHC.png",
    teams: [["398205", "14U"], ["398217", "15U"], ["398228", "17U"], ["398243", "18U"]],
  },
  {
    slug: "island-hc",
    name: "Island HC",
    location: "Vancouver Island, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Island%20Hockey%20Club%20png.png",
    teams: [["398206", "14U"], ["398218", "15U"], ["398229", "17U"]],
  },
  {
    slug: "kootenay-ha",
    name: "Kootenay HA",
    location: "Cranbrook, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Kootenay%20Hockey%20Academy%20Text%20Only%20-%20PNG.png",
    teams: [["398230", "17U"], ["398244", "18U"]],
  },
  {
    slug: "langley-ha",
    name: "Langley HA",
    location: "Langley, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Langley.png",
    teams: [["398207", "14U"], ["398219", "15U"], ["398231", "17U"], ["398245", "18U"]],
  },
  {
    slug: "lethbridge-united",
    name: "Lethbridge United",
    location: "Lethbridge, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Lethbridge%20United.png",
    teams: [["398232", "17U"], ["398246", "18U"]],
  },
  {
    slug: "northstars-ha",
    name: "Northstars HA",
    location: "Fort McMurray, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Northstar%20Hockey%20Academy%20-%20PNG.png",
    teams: [["398208", "14U"], ["398220", "15U"]],
  },
  {
    slug: "okanagan-hc",
    name: "Okanagan HC",
    location: "Kelowna, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Okanagan%20HC%20Logo%20-%20OFFICIAL.png",
    teams: [["398209", "14U"], ["398221", "15U"], ["398233", "17U"], ["398247", "18U"]],
  },
  {
    slug: "surrey-eagles-ha",
    name: "Surrey Eagles HA",
    location: "Surrey, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/SE_ACADEMEY_LOGO.png",
    teams: [["398210", "14U"], ["398222", "15U"], ["398248", "18U"]],
  },
  {
    slug: "titans-hockey-union",
    name: "Titans Hockey Union",
    location: "St. Albert, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Logo%20PNGs/Titans%20Hockey%20Union.png",
    teams: [["398211", "14U"], ["398223", "15U"], ["398234", "17U"], ["398249", "18U"]],
  },
  {
    slug: "victoria-ha",
    name: "Victoria HA",
    location: "Victoria, BC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Victoria%20HC%20On%20White%20-%20PNG.png",
    teams: [["398212", "14U"], ["398235", "17U"], ["398250", "18U"]],
  },
  {
    slug: "wolves-hc",
    name: "Wolves HC",
    location: "Spruce Grove, AB",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Wolves%20HC%20-%20PNG.png",
    teams: [["398213", "14U"], ["398236", "17U"], ["398251", "18U"]],
  },
].map((hub) => ({
  ...hub,
  id: `jphl_hub_${hub.slug.replaceAll("-", "_")}`,
  teams: hub.teams.map(([sourceId, ageGroup]) => ({
    id: `jphl_team_${sourceId}`,
    sourceId,
    ageGroup,
    division: "AAA",
    name: `${ageGroup} AAA - ${hub.name}`,
  })),
}));

const dummyHubs = new Map([
  ["okpmwURqzuRZx0bJn7mW", { name: "Calgary Canucks", teamIds: ["FvXus14Fmsb9AuoJbjxa", "seed_team_calgary_u13", "seed_team_calgary_u15"] }],
  ["seed_hub_edmonton_falcons", { name: "Edmonton Falcons", teamIds: ["seed_team_edmonton_u13", "seed_team_edmonton_u15", "seed_team_edmonton_u18"] }],
  ["seed_hub_kelowna_valley_eagles", { name: "Kelowna Valley Eagles", teamIds: ["seed_team_kelowna_u15_prep", "seed_team_kelowna_u18_prep"] }],
  ["seed_hub_lethbridge_wolves", { name: "Lethbridge Wolves", teamIds: ["seed_team_lethbridge_u15", "seed_team_lethbridge_u17"] }],
  ["seed_hub_red_deer_rangers", { name: "Red Deer Rangers", teamIds: ["seed_team_red_deer_u15", "seed_team_red_deer_u18"] }],
  ["seed_hub_saskatoon_storm", { name: "Saskatoon Storm", teamIds: ["seed_team_saskatoon_u15", "seed_team_saskatoon_u18"] }],
]);

const DUMMY_ANNOUNCEMENT_ID = "seed_announcement_calgary_ice";
const DUMMY_ANNOUNCEMENT_TITLE = "Calgary ice allocation update";
const canonicalHubIds = new Set(hubs.map((hub) => hub.id));
const canonicalTeamIds = new Set(hubs.flatMap((hub) => hub.teams.map((team) => team.id)));
const dummyHubIds = new Set(dummyHubs.keys());
const dummyTeamIds = new Set([...dummyHubs.values()].flatMap((hub) => hub.teamIds));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function arraysWithout(values, removed) {
  return Array.isArray(values) ? values.filter((value) => !removed.has(value)) : [];
}

function hasAny(values, candidates) {
  return Array.isArray(values) && values.some((value) => candidates.has(value));
}

function serialize(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return { __type: "timestamp", seconds: value.seconds, nanoseconds: value.nanoseconds };
  }
  if (value instanceof admin.firestore.GeoPoint) {
    return { __type: "geopoint", latitude: value.latitude, longitude: value.longitude };
  }
  if (value instanceof admin.firestore.DocumentReference) {
    return { __type: "reference", path: value.path };
  }
  if (Buffer.isBuffer(value)) return { __type: "buffer", base64: value.toString("base64") };
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialize(item)]));
  }
  return value;
}

function backupDoc(doc) {
  return { path: doc.ref.path, data: serialize(doc.data()) };
}

async function fetchBytes(url, label) {
  const response = await fetch(url, { redirect: "follow" });
  assert(response.ok, `${label} returned HTTP ${response.status}: ${url}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  assert(bytes.length > 100, `${label} returned an unexpectedly small file (${bytes.length} bytes)`);
  return { bytes, contentType: response.headers.get("content-type") || "application/octet-stream" };
}

async function loadState(db) {
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  const [orgDoc, leagueDoc, hubDocs, userDocs, invitationDocs, roomDocs, announcementDocs] = await Promise.all([
    orgRef.get(),
    leagueRef.get(),
    leagueRef.collection("hubs").get(),
    db.collection("users").where("orgId", "==", ORG_ID).get(),
    orgRef.collection("invitations").get(),
    orgRef.collection("chatRooms").get(),
    orgRef.collection("announcements").get(),
  ]);

  assert(orgDoc.exists, `Organization ${ORG_ID} does not exist`);
  assert(orgDoc.data().name === "JPHL", `Expected organization JPHL, found ${orgDoc.data().name}`);
  assert(leagueDoc.exists, `League ${LEAGUE_ID} does not exist`);
  assert(leagueDoc.data().name === "Junior Prospects Hockey League", `Unexpected league: ${leagueDoc.data().name}`);

  const allowedHubIds = new Set([...dummyHubIds, ...canonicalHubIds]);
  const unexpectedHubs = hubDocs.docs.filter((doc) => !allowedHubIds.has(doc.id));
  assert(unexpectedHubs.length === 0, `Refusing to continue with unapproved hubs: ${unexpectedHubs.map((doc) => `${doc.id} (${doc.data().name})`).join(", ")}`);

  for (const doc of hubDocs.docs) {
    const expected = dummyHubs.get(doc.id);
    if (expected) assert(doc.data().name === expected.name, `Dummy hub ${doc.id} has unexpected name ${doc.data().name}`);
  }

  const oldHubDocs = hubDocs.docs.filter((doc) => dummyHubIds.has(doc.id));
  const oldTeamDocs = [];
  for (const hubDoc of oldHubDocs) {
    const teams = await hubDoc.ref.collection("teams").get();
    const expectedTeamIds = new Set(dummyHubs.get(hubDoc.id).teamIds);
    const unexpectedTeams = teams.docs.filter((doc) => !expectedTeamIds.has(doc.id));
    assert(unexpectedTeams.length === 0, `Dummy hub ${hubDoc.id} contains unapproved teams: ${unexpectedTeams.map((doc) => doc.id).join(", ")}`);
    oldTeamDocs.push(...teams.docs);
  }

  const staleUsers = userDocs.docs.filter((doc) => hasAny(doc.data().hubIds, dummyHubIds) || hasAny(doc.data().teamIds, dummyTeamIds));
  const staleInvitations = invitationDocs.docs.filter((doc) => hasAny(doc.data().hubIds, dummyHubIds) || hasAny(doc.data().teamIds, dummyTeamIds));
  const oldRooms = roomDocs.docs.filter((doc) => dummyHubIds.has(doc.data().hubId));
  const unexpectedTargetedAnnouncements = announcementDocs.docs.filter((doc) => dummyHubIds.has(doc.data().hubId) && doc.id !== DUMMY_ANNOUNCEMENT_ID);
  assert(unexpectedTargetedAnnouncements.length === 0, `Unapproved announcements target dummy hubs: ${unexpectedTargetedAnnouncements.map((doc) => doc.id).join(", ")}`);

  const dummyAnnouncement = announcementDocs.docs.find((doc) => doc.id === DUMMY_ANNOUNCEMENT_ID);
  if (dummyAnnouncement) {
    assert(dummyAnnouncement.data().title === DUMMY_ANNOUNCEMENT_TITLE, `Dummy announcement has unexpected title: ${dummyAnnouncement.data().title}`);
    assert(dummyHubIds.has(dummyAnnouncement.data().hubId), "Dummy announcement no longer targets a dummy hub");
  }

  const roomMessages = [];
  for (const room of oldRooms) {
    const messages = await room.ref.collection("messages").get();
    roomMessages.push(...messages.docs);
  }

  return {
    orgRef,
    leagueRef,
    orgDoc,
    leagueDoc,
    hubDocs: hubDocs.docs,
    oldHubDocs,
    oldTeamDocs,
    userDocs: userDocs.docs,
    invitationDocs: invitationDocs.docs,
    roomDocs: roomDocs.docs,
    announcementDocs: announcementDocs.docs,
    staleUsers,
    staleInvitations,
    oldRooms,
    roomMessages,
    dummyAnnouncement,
  };
}

async function validateOfficialSource() {
  const [{ bytes: directory }, ...logos] = await Promise.all([
    fetchBytes(DIRECTORY_URL, "Official directory"),
    ...hubs.map((hub) => fetchBytes(hub.logoSource, `${hub.name} logo`)),
  ]);
  const directoryHtml = directory.toString("utf8");
  for (const team of hubs.flatMap((hub) => hub.teams)) {
    assert(directoryHtml.includes(team.sourceId), `Official directory no longer includes team ${team.sourceId} (${team.name})`);
  }
  for (const [index, logo] of logos.entries()) {
    assert(logo.contentType.toLowerCase().includes("image"), `${hubs[index].name} source is not an image (${logo.contentType})`);
  }
  return logos;
}

function printPlan(state, logos) {
  console.log(`${APPLY ? "APPLY" : "DRY RUN"}: ${hubs.length} hubs, ${hubs.flatMap((hub) => hub.teams).length} teams`);
  for (const hub of hubs) console.log(`  + ${hub.name}: ${hub.teams.map((team) => team.ageGroup).join(", ")}`);
  console.log(`  - dummy hubs present: ${state.oldHubDocs.length}`);
  console.log(`  - dummy teams present: ${state.oldTeamDocs.length}`);
  console.log(`  - dummy hub rooms present: ${state.oldRooms.length} (${state.roomMessages.length} messages)`);
  console.log(`  - stale user assignments: ${state.staleUsers.length}`);
  console.log(`  - stale invitation assignments: ${state.staleInvitations.length}`);
  console.log(`  - dummy announcement present: ${Boolean(state.dummyAnnouncement)}`);
  console.log(`  - official logos validated: ${logos.length} (${logos.reduce((sum, logo) => sum + logo.bytes.length, 0)} bytes)`);
}

function writeBackup(state) {
  const timestamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  const backupDir = path.resolve(__dirname, "../../.codex-backups");
  fs.mkdirSync(backupDir, { recursive: true, mode: 0o700 });
  const backupPath = path.join(backupDir, `jphl-structure-production-${timestamp}.json`);
  const documents = [
    state.orgDoc,
    state.leagueDoc,
    ...state.hubDocs,
    ...state.oldTeamDocs,
    ...state.userDocs,
    ...state.invitationDocs,
    ...state.roomDocs,
    ...state.roomMessages,
    ...state.announcementDocs,
  ].map(backupDoc);
  fs.writeFileSync(backupPath, `${JSON.stringify({ projectId: PROJECT_ID, createdAt: new Date().toISOString(), documents }, null, 2)}\n`, { mode: 0o600 });
  return backupPath;
}

async function uploadLogos(bucket, logos) {
  const urls = new Map();
  for (const [index, hub] of hubs.entries()) {
    const objectPath = `organizations/${ORG_ID}/hubs/${hub.id}/logo.png`;
    const file = bucket.file(objectPath);
    let token = randomUUID();
    try {
      const [metadata] = await file.getMetadata();
      const existing = metadata.metadata?.firebaseStorageDownloadTokens;
      if (typeof existing === "string" && existing.length > 0) token = existing.split(",")[0];
    } catch (error) {
      if (error.code !== 404) throw error;
    }
    await file.save(logos[index].bytes, {
      resumable: false,
      contentType: "image/png",
      metadata: {
        cacheControl: "public,max-age=86400",
        metadata: {
          firebaseStorageDownloadTokens: token,
          sourceUrl: hub.logoSource,
          sourceSite: "juniorprospectshockeyleague.com",
        },
      },
    });
    const url = `https://firebasestorage.googleapis.com/v0/b/${STORAGE_BUCKET}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
    urls.set(hub.id, url);
    console.log(`Uploaded ${hub.name} logo`);
  }
  return urls;
}

async function writeCanonicalStructure(db, state, logoUrls) {
  const now = admin.firestore.Timestamp.now();
  const existingHubs = new Map(state.hubDocs.map((doc) => [doc.id, doc]));
  let batch = db.batch();
  let pending = 0;
  const commit = async () => {
    if (pending === 0) return;
    await batch.commit();
    batch = db.batch();
    pending = 0;
  };
  const set = async (ref, data, options) => {
    batch.set(ref, data, options);
    pending += 1;
    if (pending >= 400) await commit();
  };

  await set(state.orgRef, {
    scheduleIntegration: {
      provider: "ramp",
      enabled: true,
      autoDiscoverSeason: true,
      baseUrl: "https://juniorprospectshockeyleague.com",
      associationId: "2888",
      seasonId: CURRENT_SEASON_ID,
      legacySourceSeasonId: LEGACY_SEASON_ID,
      timezone: "America/Edmonton",
      divisionIds: RAMP_DIVISION_IDS,
      updatedAt: now,
      updatedBy: "reconcile-jphl-structure",
    },
  }, { merge: true });

  for (const hub of hubs) {
    const hubRef = state.leagueRef.collection("hubs").doc(hub.id);
    const logoUrl = logoUrls.get(hub.id);
    await set(hubRef, {
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      name: hub.name,
      location: hub.location,
      logoUrl,
      iconName: null,
      ...(existingHubs.has(hub.id) ? {} : { createdAt: now }),
    }, { merge: true });

    for (const team of hub.teams) {
      const teamRef = hubRef.collection("teams").doc(team.id);
      const existing = await teamRef.get();
      await set(teamRef, {
        orgId: ORG_ID,
        leagueId: LEAGUE_ID,
        hubId: hub.id,
        name: team.name,
        ageGroup: team.ageGroup,
        division: team.division,
        logoUrl,
        iconName: null,
        memberIds: existing.exists && Array.isArray(existing.data().memberIds) ? existing.data().memberIds : [],
        sourceTeamId: team.sourceId,
        sourceDivisionId: RAMP_DIVISION_IDS[team.ageGroup],
        sourceUrl: DIRECTORY_URL,
        ...(existing.exists ? {} : { createdAt: now }),
      }, { merge: true });
    }

    const roomRef = state.orgRef.collection("chatRooms").doc(`jphl_hub_room_${hub.slug.replaceAll("-", "_")}`);
    await set(roomRef, {
      orgId: ORG_ID,
      name: `${hub.name} - General`,
      type: "league",
      leagueId: LEAGUE_ID,
      hubId: hub.id,
      teamId: null,
      participants: [],
      isArchived: false,
      createdAt: now,
      lastMessage: null,
      lastMessageAt: now,
      lastMessageBy: null,
      roomIconName: null,
      roomImageUrl: logoUrl,
    }, { merge: true });
  }
  await commit();
}

async function cleanAssignments(db, docs) {
  let batch = db.batch();
  let pending = 0;
  for (const doc of docs) {
    const data = doc.data();
    const hubIds = arraysWithout(data.hubIds, dummyHubIds);
    const teamIds = arraysWithout(data.teamIds, dummyTeamIds);
    if (JSON.stringify(hubIds) === JSON.stringify(data.hubIds || []) && JSON.stringify(teamIds) === JSON.stringify(data.teamIds || [])) continue;
    batch.update(doc.ref, { hubIds, teamIds });
    pending += 1;
    if (pending >= 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

async function removeDummyData(db, state) {
  await cleanAssignments(db, state.userDocs);
  await cleanAssignments(db, state.invitationDocs);
  if (state.dummyAnnouncement) await state.dummyAnnouncement.ref.delete();
  for (const room of state.oldRooms) await db.recursiveDelete(room.ref);
  for (const hub of state.oldHubDocs) await db.recursiveDelete(hub.ref);
}

async function verify(db) {
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  const [hubDocs, userDocs, invitationDocs, roomDocs, announcementDocs] = await Promise.all([
    leagueRef.collection("hubs").get(),
    db.collection("users").where("orgId", "==", ORG_ID).get(),
    orgRef.collection("invitations").get(),
    orgRef.collection("chatRooms").get(),
    orgRef.collection("announcements").get(),
  ]);
  assert(hubDocs.size === 18, `Expected 18 hubs, found ${hubDocs.size}`);
  assert(hubDocs.docs.every((doc) => canonicalHubIds.has(doc.id)), "Non-canonical hub remains after migration");

  let teamCount = 0;
  const logoUrls = [];
  for (const hubDoc of hubDocs.docs) {
    const teams = await hubDoc.ref.collection("teams").get();
    teamCount += teams.size;
    assert(teams.docs.every((doc) => canonicalTeamIds.has(doc.id)), `Unexpected team under ${hubDoc.id}`);
    assert(teams.docs.every((doc) => doc.data().hubId === hubDoc.id), `Team has incorrect hubId under ${hubDoc.id}`);
    assert(teams.docs.every((doc) => doc.data().logoUrl === hubDoc.data().logoUrl), `Team logo differs from hub logo under ${hubDoc.id}`);
    logoUrls.push(hubDoc.data().logoUrl);
  }
  assert(teamCount === 50, `Expected 50 teams, found ${teamCount}`);
  assert(userDocs.docs.every((doc) => !hasAny(doc.data().hubIds, dummyHubIds) && !hasAny(doc.data().teamIds, dummyTeamIds)), "A user still references dummy structure");
  assert(invitationDocs.docs.every((doc) => !hasAny(doc.data().hubIds, dummyHubIds) && !hasAny(doc.data().teamIds, dummyTeamIds)), "An invitation still references dummy structure");
  assert(announcementDocs.docs.every((doc) => !dummyHubIds.has(doc.data().hubId)), "An announcement still targets dummy structure");

  const activeHubRooms = roomDocs.docs.filter((doc) => doc.data().leagueId === LEAGUE_ID && doc.data().hubId && doc.data().isArchived !== true);
  assert(activeHubRooms.length === 18, `Expected 18 active hub rooms, found ${activeHubRooms.length}`);
  assert(activeHubRooms.every((doc) => canonicalHubIds.has(doc.data().hubId)), "A dummy hub room remains");
  assert(activeHubRooms.every((doc) => doc.data().roomImageUrl === hubDocs.docs.find((hub) => hub.id === doc.data().hubId).data().logoUrl), "A hub room logo is out of sync");

  const checks = await Promise.all(logoUrls.map((url) => fetch(url, { method: "HEAD" })));
  assert(checks.every((response) => response.ok), `One or more Firebase logo URLs failed: ${checks.map((response) => response.status).join(", ")}`);
  return { hubs: hubDocs.size, teams: teamCount, hubRooms: activeHubRooms.length, logoUrls: logoUrls.length };
}

async function main() {
  const app = admin.initializeApp({ projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET }, "jphl-structure-reconciliation");
  const db = admin.firestore(app);
  db.settings({ ignoreUndefinedProperties: true });
  const bucket = admin.storage(app).bucket();

  console.log(`Target project: ${PROJECT_ID}`);
  const [state, logos] = await Promise.all([loadState(db), validateOfficialSource()]);
  printPlan(state, logos);
  if (!APPLY) {
    console.log("Dry run passed. Re-run with --apply to back up and reconcile production.");
    return;
  }

  const backupPath = writeBackup(state);
  console.log(`Backup written: ${backupPath}`);
  const logoUrls = await uploadLogos(bucket, logos);
  await writeCanonicalStructure(db, state, logoUrls);
  await removeDummyData(db, state);
  const verification = await verify(db);
  await state.orgRef.collection("auditLogs").add({
    action: "reconcileJphlStructure",
    actorId: "system-production-migration",
    actorName: "Codex production migration",
    actorEmail: null,
    actorRole: "system",
    request: {
      approvedPlan: "Replace approved dummy structure from the official JPHL directory",
      sourceUrl: DIRECTORY_URL,
    },
    result: {
      ...verification,
      removedDummyHubs: state.oldHubDocs.length,
      removedDummyTeams: state.oldTeamDocs.length,
      cleanedUsers: state.staleUsers.length,
      cleanedInvitations: state.staleInvitations.length,
      removedDummyRooms: state.oldRooms.length,
      removedDummyAnnouncement: Boolean(state.dummyAnnouncement),
      backupFile: path.basename(backupPath),
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Verification passed: ${JSON.stringify(verification)}`);
  console.log("Production JPHL structure reconciliation completed successfully.");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.stack || error);
    process.exitCode = 1;
  });
}

module.exports = {
  CURRENT_SEASON_ID,
  RAMP_DIVISION_IDS,
  hubs,
};
