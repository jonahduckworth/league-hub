#!/usr/bin/env node

/*
 * Reconciles the production JPHL structure with the official JPHL directory.
 *
 * Safety defaults:
 *   node scripts/reconcile-jphl-structure.js          # validate and dry-run
 *   node scripts/reconcile-jphl-structure.js --apply  # back up, then mutate
 *   node scripts/reconcile-jphl-structure.js --restore <backup> --apply
 */

const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  matchRampDirectory,
  parseRampDirectory,
} = require("../lib/schedule/rampDiscovery");

const PROJECT_ID = "jdb-league-hub";
const ORG_ID = "JMl7VkKm9tAADBaxxdiI";
const LEAGUE_ID = "KHuoFdO37RD0i2ARocIl";
const DIRECTORY_URL = "https://juniorprospectshockeyleague.com";
const CURRENT_SEASON_ID = "14553";
const LEGACY_SEASON_ID = "12322";
const MIGRATION_ID = "jphl-structure-2026-27";
const BACKUP_DIR = path.resolve(__dirname, "../../.codex-backups");
const RAMP_DIVISION_IDS = {
  "14U": "16624",
  "15U": "16623",
  "17U": "23859",
  "18U": "16622",
};
const APPLY = process.argv.includes("--apply");
const restoreIndex = process.argv.indexOf("--restore");
const RESTORE_PATH = restoreIndex >= 0 ? process.argv[restoreIndex + 1] : undefined;
const consumedArgs = new Set(["--apply"]);
if (restoreIndex >= 0) {
  assertCliArgument(
    RESTORE_PATH && !RESTORE_PATH.startsWith("--"),
    "--restore requires a backup path",
  );
  consumedArgs.add("--restore");
  consumedArgs.add(RESTORE_PATH);
}
const UNKNOWN_ARGS = process.argv.slice(2).filter((arg) => !consumedArgs.has(arg));

if (UNKNOWN_ARGS.length > 0) {
  throw new Error(`Unknown arguments: ${UNKNOWN_ARGS.join(", ")}`);
}

function assertCliArgument(condition, message) {
  if (!condition) throw new Error(message);
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
    name: "EPIC Hockey Academy",
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
    teams: [["398221", "15U"], ["398233", "17U"], ["398247", "18U"]],
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
    teams: [["398212", "14U"], ["398235", "17U"]],
  },
  {
    slug: "velocity-ha",
    name: "Velocity HA",
    location: "Montreal, QC",
    logoSource: "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Colour Logo_on blk@2x.png",
    teams: [["399986", "18U"]],
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
const dummyHubIds = new Set(dummyHubs.keys());
const dummyTeamIds = new Set([...dummyHubs.values()].flatMap((hub) => hub.teamIds));
const approvedTeamAliases = new Map([
  ["18U:epic ha", "18U:epic hockey academy"],
  ["18U:junior capitals", "18U:cowichan jr capitals"],
]);
const approvedRetiredTeams = new Map([
  ["14U:okanagan hc", "398209"],
  ["18U:victoria ha", "398250"],
]);
const approvedRetiredHubRooms = new Map([
  ["jphl_hub_room_lloydminster_athletics", "jphl_hub_lloydminster_athletics"],
  ["jphl_hub_room_south_sask_hc", "jphl_hub_south_sask_hc"],
]);
const approvedRetiredHubIds = new Set(approvedRetiredHubRooms.values());

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function arraysWithout(values, removed) {
  return Array.isArray(values) ? values.filter((value) => !removed.has(value)) : [];
}

function hasAny(values, candidates) {
  return Array.isArray(values) && values.some((value) => candidates.has(value));
}

function teamKey(name, ageGroup) {
  const normalizedAgeGroup = typeof ageGroup === "string" && ageGroup.trim()
    ? ageGroup.trim().toUpperCase()
    : String(name).match(/\b(\d{2}U)\b/i)?.[1].toUpperCase();
  const club = String(name)
    .replace(/^\s*\d{2}U(?:\s+AAA)?\s*[-–—:]\s*/i, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
  return normalizedAgeGroup && club ? `${normalizedAgeGroup}:${club}` : undefined;
}

function desiredTeamEntries() {
  return hubs.flatMap((hub) => hub.teams.map((team) => ({
    ...team,
    hubId: hub.id,
    hubName: hub.name,
    key: teamKey(team.name, team.ageGroup),
  })));
}

function buildTeamPlan(existingTeams) {
  const desired = desiredTeamEntries();
  const desiredByKey = new Map(desired.map((team) => [team.key, team]));
  assert(desiredByKey.size === desired.length, "The approved JPHL manifest contains duplicate team names");

  const claimed = new Set();
  const items = [];
  const retired = [];
  for (const existing of existingTeams) {
    const rawKey = teamKey(existing.name, existing.ageGroup);
    const key = approvedTeamAliases.get(rawKey) ?? rawKey;
    const target = desiredByKey.get(key);
    if (!target) {
      const retiredSourceId = approvedRetiredTeams.get(key);
      const matchesApprovedRetirement = retiredSourceId &&
        (existing.sourceTeamId === retiredSourceId || existing.id === `jphl_team_${retiredSourceId}`);
      assert(
        matchesApprovedRetirement,
        `Refusing to remove unexpected team ${existing.id} (${existing.name})`,
      );
      retired.push(existing);
      continue;
    }
    assert(!claimed.has(key), `Multiple League Hub teams map to ${target.name}`);
    claimed.add(key);
    items.push({
      kind: existing.hubId === target.hubId ? "update" : "move",
      existing,
      target,
      targetId: existing.id,
    });
  }

  for (const target of desired) {
    if (claimed.has(target.key)) continue;
    items.push({ kind: "create", target, targetId: target.id });
  }
  assert(items.length === desired.length, `Expected ${desired.length} planned teams, found ${items.length}`);
  return { items, retired };
}

function assignmentPatch(data, plan) {
  const retiredIds = new Set(plan.retired.map((team) => team.id));
  const teamIds = arraysWithout(arraysWithout(data.teamIds, dummyTeamIds), retiredIds);
  const hubIds = arraysWithout(arraysWithout(data.hubIds, dummyHubIds), approvedRetiredHubIds);
  for (const item of plan.items) {
    if (item.kind !== "move" || !teamIds.includes(item.existing.id)) continue;
    if (!hubIds.includes(item.target.hubId)) hubIds.push(item.target.hubId);
  }
  const patch = {};
  if (JSON.stringify(teamIds) !== JSON.stringify(data.teamIds || [])) patch.teamIds = teamIds;
  if (JSON.stringify(hubIds) !== JSON.stringify(data.hubIds || [])) patch.hubIds = hubIds;
  return patch;
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

function deserialize(value, db) {
  if (Array.isArray(value)) return value.map((item) => deserialize(item, db));
  if (!value || typeof value !== "object") return value;
  if (value.__type === "timestamp") {
    return new admin.firestore.Timestamp(value.seconds, value.nanoseconds);
  }
  if (value.__type === "geopoint") {
    return new admin.firestore.GeoPoint(value.latitude, value.longitude);
  }
  if (value.__type === "reference") return db.doc(value.path);
  if (value.__type === "buffer") return Buffer.from(value.base64, "base64");
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, deserialize(item, db)]),
  );
}

function updateTimeToken(snapshot) {
  if (!snapshot.exists) return null;
  return `${snapshot.updateTime.seconds}:${snapshot.updateTime.nanoseconds}`;
}

function backupDoc(doc) {
  return {
    path: doc.ref.path,
    data: serialize(doc.data()),
    updateTime: updateTimeToken(doc),
  };
}

function inventoryOf(documents) {
  return new Map(documents.map((doc) => [doc.ref.path, updateTimeToken(doc)]));
}

function compareInventories(expected, actual) {
  const missing = [...expected.keys()].filter((key) => !actual.has(key));
  const added = [...actual.keys()].filter((key) => !expected.has(key));
  const changed = [...expected.keys()].filter((key) =>
    actual.has(key) && actual.get(key) !== expected.get(key));
  return { missing, added, changed };
}

async function fetchBytes(url, label) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await fetch(url, {
        redirect: "follow",
        signal: AbortSignal.timeout(15_000),
      });
      assert(response.ok, `${label} returned HTTP ${response.status}: ${url}`);
      const bytes = Buffer.from(await response.arrayBuffer());
      assert(bytes.length > 100, `${label} returned an unexpectedly small file (${bytes.length} bytes)`);
      return { bytes, contentType: response.headers.get("content-type") || "application/octet-stream" };
    } catch (error) {
      lastError = error;
      if (attempt < 3) await new Promise((resolve) => setTimeout(resolve, attempt * 250));
    }
  }
  throw new Error(`${label} fetch failed after 3 attempts: ${lastError?.message ?? lastError}`);
}

async function loadState(db) {
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  const migrationRef = orgRef.collection("auditLogs").doc(MIGRATION_ID);
  const [orgDoc, leagueDoc, migrationDoc, hubDocs, userDocs, invitationDocs, roomDocs, announcementDocs] = await Promise.all([
    orgRef.get(),
    leagueRef.get(),
    migrationRef.get(),
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

  const teamDocs = [];
  const oldHubDocs = hubDocs.docs.filter((doc) => dummyHubIds.has(doc.id));
  const oldTeamDocs = [];
  for (const hubDoc of hubDocs.docs) {
    const teams = await hubDoc.ref.collection("teams").get();
    teamDocs.push(...teams.docs);
    if (dummyHubIds.has(hubDoc.id)) {
      const expectedTeamIds = new Set(dummyHubs.get(hubDoc.id).teamIds);
      const unexpectedTeams = teams.docs.filter((doc) => !expectedTeamIds.has(doc.id));
      assert(unexpectedTeams.length === 0, `Dummy hub ${hubDoc.id} contains unapproved teams: ${unexpectedTeams.map((doc) => doc.id).join(", ")}`);
      oldTeamDocs.push(...teams.docs);
    }
  }

  const staleUsers = userDocs.docs.filter((doc) => hasAny(doc.data().hubIds, dummyHubIds) || hasAny(doc.data().teamIds, dummyTeamIds));
  const staleInvitations = invitationDocs.docs.filter((doc) => hasAny(doc.data().hubIds, dummyHubIds) || hasAny(doc.data().teamIds, dummyTeamIds));
  const oldRooms = roomDocs.docs.filter((doc) => dummyHubIds.has(doc.data().hubId));
  const retiredRooms = roomDocs.docs.filter((doc) =>
    approvedRetiredHubRooms.has(doc.id) &&
    approvedRetiredHubRooms.get(doc.id) === doc.data().hubId,
  );
  const unexpectedActiveHubRooms = roomDocs.docs.filter((doc) =>
    doc.data().leagueId === LEAGUE_ID &&
    doc.data().hubId &&
    doc.data().isArchived !== true &&
    !canonicalHubIds.has(doc.data().hubId) &&
    !dummyHubIds.has(doc.data().hubId) &&
    !approvedRetiredHubIds.has(doc.data().hubId),
  );
  assert(unexpectedActiveHubRooms.length === 0, `Unapproved active hub rooms: ${unexpectedActiveHubRooms.map((doc) => doc.id).join(", ")}`);
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
    migrationRef,
    migrationDoc,
    orgDoc,
    leagueDoc,
    hubDocs: hubDocs.docs,
    teamDocs,
    oldHubDocs,
    oldTeamDocs,
    userDocs: userDocs.docs,
    invitationDocs: invitationDocs.docs,
    roomDocs: roomDocs.docs,
    announcementDocs: announcementDocs.docs,
    staleUsers,
    staleInvitations,
    oldRooms,
    retiredRooms,
    roomMessages,
    dummyAnnouncement,
  };
}

function stateDocuments(state) {
  return [
    state.orgDoc,
    state.leagueDoc,
    ...(state.migrationDoc.exists ? [state.migrationDoc] : []),
    ...state.hubDocs,
    ...state.teamDocs,
    ...state.userDocs,
    ...state.invitationDocs,
    ...state.roomDocs,
    ...state.roomMessages,
    ...state.announcementDocs,
  ];
}

async function transactionStateDocuments(transaction, state) {
  const documents = [];
  documents.push(await transaction.get(state.orgRef));
  documents.push(await transaction.get(state.leagueRef));
  const hubSnapshot = await transaction.get(state.leagueRef.collection("hubs"));
  documents.push(...hubSnapshot.docs);

  const hubIds = new Set([...state.hubDocs.map((doc) => doc.id), ...canonicalHubIds]);
  for (const hubId of hubIds) {
    const teams = await transaction.get(
      state.leagueRef.collection("hubs").doc(hubId).collection("teams"),
    );
    documents.push(...teams.docs);
  }

  const [users, invitations, rooms, announcements] = await Promise.all([
    transaction.get(dbCollectionQuery(state.orgRef.firestore, "users", "orgId", ORG_ID)),
    transaction.get(state.orgRef.collection("invitations")),
    transaction.get(state.orgRef.collection("chatRooms")),
    transaction.get(state.orgRef.collection("announcements")),
  ]);
  documents.push(...users.docs, ...invitations.docs, ...rooms.docs, ...announcements.docs);
  for (const room of state.oldRooms) {
    const messages = await transaction.get(room.ref.collection("messages"));
    documents.push(...messages.docs);
  }
  return documents;
}

function dbCollectionQuery(db, collection, field, value) {
  return db.collection(collection).where(field, "==", value);
}

async function validateOfficialSource() {
  const { bytes: directory } = await fetchBytes(DIRECTORY_URL, "Official directory");
  const logos = [];
  for (const hub of hubs) logos.push(await fetchBytes(hub.logoSource, `${hub.name} logo`));
  const directoryHtml = directory.toString("utf8");
  const configured = desiredTeamEntries().map((team) => ({
    id: team.id,
    name: team.name,
    ageGroup: team.ageGroup,
  }));
  const discovery = matchRampDirectory(parseRampDirectory(directoryHtml), configured);
  assert(
    discovery.status === "matched" &&
      discovery.discoveredSeasonId === CURRENT_SEASON_ID &&
      discovery.matchedTeams === configured.length &&
      discovery.discoveredTeams === configured.length,
    `Official directory is no longer an exact ${configured.length}-team match: ${discovery.message}`,
  );
  for (const team of hubs.flatMap((hub) => hub.teams)) {
    assert(directoryHtml.includes(team.sourceId), `Official directory no longer includes team ${team.sourceId} (${team.name})`);
  }
  for (const [index, logo] of logos.entries()) {
    assert(logo.contentType.toLowerCase().includes("image"), `${hubs[index].name} source is not an image (${logo.contentType})`);
  }
  return logos;
}

function printPlan(state, logos, plan) {
  console.log(`${APPLY ? "APPLY" : "DRY RUN"}: ${hubs.length} hubs, ${hubs.flatMap((hub) => hub.teams).length} teams`);
  for (const hub of hubs) console.log(`  + ${hub.name}: ${hub.teams.map((team) => team.ageGroup).join(", ")}`);
  console.log(`  - dummy hubs present: ${state.oldHubDocs.length}`);
  console.log(`  - dummy teams present: ${state.oldTeamDocs.length}`);
  console.log(`  - dummy hub rooms present: ${state.oldRooms.length} (${state.roomMessages.length} messages)`);
  console.log(`  - approved retired hub rooms to archive: ${state.retiredRooms.length}`);
  console.log(`  - stale user assignments: ${state.staleUsers.length}`);
  console.log(`  - stale invitation assignments: ${state.staleInvitations.length}`);
  console.log(`  - dummy announcement present: ${Boolean(state.dummyAnnouncement)}`);
  console.log(`  - existing teams updated in place: ${plan.items.filter((item) => item.kind === "update").length}`);
  console.log(`  - existing teams moved without changing IDs: ${plan.items.filter((item) => item.kind === "move").length}`);
  console.log(`  - new teams: ${plan.items.filter((item) => item.kind === "create").length}`);
  console.log(`  - approved retired teams: ${plan.retired.length}`);
  console.log(`  - official logos validated: ${logos.length} (${logos.reduce((sum, logo) => sum + logo.bytes.length, 0)} bytes)`);
}

function plannedCreatedPaths(state, plan) {
  const existingPaths = new Set(stateDocuments(state).map((doc) => doc.ref.path));
  const paths = new Set();
  for (const hub of hubs) {
    const hubRef = state.leagueRef.collection("hubs").doc(hub.id);
    const roomRef = state.orgRef.collection("chatRooms")
      .doc(`jphl_hub_room_${hub.slug.replaceAll("-", "_")}`);
    if (!existingPaths.has(hubRef.path)) paths.add(hubRef.path);
    if (!existingPaths.has(roomRef.path)) paths.add(roomRef.path);
  }
  for (const item of plan.items.filter((item) => item.kind === "create" || item.kind === "move")) {
    const targetRef = state.leagueRef.collection("hubs").doc(item.target.hubId)
      .collection("teams").doc(item.targetId);
    if (!existingPaths.has(targetRef.path)) paths.add(targetRef.path);
  }
  if (!state.migrationDoc.exists) paths.add(state.migrationRef.path);
  return [...paths].sort();
}

function writeBackup(state, plan) {
  const timestamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  fs.mkdirSync(BACKUP_DIR, { recursive: true, mode: 0o700 });
  const backupPath = path.join(BACKUP_DIR, `jphl-structure-production-${timestamp}.json`);
  const documents = stateDocuments(state).map(backupDoc);
  const backup = {
    schemaVersion: 1,
    projectId: PROJECT_ID,
    organizationId: ORG_ID,
    leagueId: LEAGUE_ID,
    migrationId: MIGRATION_ID,
    createdAt: new Date().toISOString(),
    createdPaths: plannedCreatedPaths(state, plan),
    documents,
  };
  fs.writeFileSync(backupPath, `${JSON.stringify(backup, null, 2)}\n`, { mode: 0o600 });
  return backupPath;
}

function validatedBackupPath(inputPath) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true, mode: 0o700 });
  const resolved = fs.realpathSync(path.resolve(inputPath));
  const realBackupDir = fs.realpathSync(BACKUP_DIR);
  assert(path.dirname(resolved) === realBackupDir, "Restore file must be directly inside .codex-backups");
  assert(path.basename(resolved).startsWith("jphl-structure-production-"), "Unexpected restore filename");
  return resolved;
}

function readBackup(inputPath) {
  const backupPath = validatedBackupPath(inputPath);
  const backup = JSON.parse(fs.readFileSync(backupPath, "utf8"));
  assert(backup.schemaVersion === 1, "Unsupported structure backup schema");
  assert(backup.projectId === PROJECT_ID, "Backup targets a different Firebase project");
  assert(backup.organizationId === ORG_ID, "Backup targets a different organization");
  assert(backup.leagueId === LEAGUE_ID, "Backup targets a different league");
  assert(backup.migrationId === MIGRATION_ID, "Backup belongs to a different migration");
  assert(Array.isArray(backup.documents) && backup.documents.length > 0, "Backup has no documents");
  assert(Array.isArray(backup.createdPaths), "Backup has no created-path inventory");
  assert(backup.postApplyGuard && typeof backup.postApplyGuard === "object", "Backup was not finalized after apply");
  const originalPaths = new Set(backup.documents.map((doc) => doc.path));
  assert(backup.createdPaths.every((item) => !originalPaths.has(item)), "Backup created paths overlap original documents");
  return { backup, backupPath };
}

async function finalizeBackup(db, backupPath) {
  const backup = JSON.parse(fs.readFileSync(backupPath, "utf8"));
  const guardedPaths = new Set([
    ...backup.documents.map((doc) => doc.path),
    ...backup.createdPaths,
  ]);
  const postApplyState = await loadState(db);
  const postApplyGuard = inventoryOf(stateDocuments(postApplyState));
  for (const guardedPath of guardedPaths) {
    if (!postApplyGuard.has(guardedPath)) postApplyGuard.set(guardedPath, null);
  }
  assert(
    backup.createdPaths.every((createdPath) => postApplyGuard.get(createdPath) != null),
    "One or more planned documents were not created",
  );
  backup.appliedAt = new Date().toISOString();
  backup.postApplyGuard = Object.fromEntries([...postApplyGuard.entries()].sort());
  const tempPath = `${backupPath}.tmp`;
  fs.writeFileSync(tempPath, `${JSON.stringify(backup, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(tempPath, backupPath);
}

async function restoreBackup(db, inputPath) {
  assert(APPLY, "Restore is a production mutation and requires --apply");
  const { backup, backupPath } = readBackup(inputPath);
  const expected = new Map(Object.entries(backup.postApplyGuard));
  const writes = backup.documents.length + backup.createdPaths.length;
  assert(writes < 450, `Refusing oversized restore transaction with ${writes} writes`);
  const currentState = await loadState(db);

  await db.runTransaction(async (transaction) => {
    const currentDocuments = await transactionStateDocuments(transaction, currentState);
    const migrationDoc = await transaction.get(currentState.migrationRef);
    if (migrationDoc.exists) currentDocuments.push(migrationDoc);
    const actual = inventoryOf(currentDocuments);
    const directPaths = [...expected.keys()].filter((docPath) => !actual.has(docPath));
    const directSnapshots = await Promise.all(
      directPaths.map((docPath) => transaction.get(db.doc(docPath))),
    );
    for (const snapshot of directSnapshots) {
      actual.set(snapshot.ref.path, updateTimeToken(snapshot));
    }
    const difference = compareInventories(expected, actual);
    assert(
      difference.missing.length === 0 && difference.added.length === 0 && difference.changed.length === 0,
      `Refusing restore because production changed after migration: ${JSON.stringify(difference)}`,
    );
    for (const document of backup.documents) {
      transaction.set(db.doc(document.path), deserialize(document.data, db));
    }
    for (const createdPath of backup.createdPaths) transaction.delete(db.doc(createdPath));
  });
  console.log(`Guarded restore completed from ${backupPath}`);
  console.log("Disable/remove the schedule functions and remove imported scheduleEvents separately if the initial sync already ran.");
}

function resolveLogoUrls(state) {
  const existingHubs = new Map(state.hubDocs.map((doc) => [doc.id, doc.data()]));
  return new Map(hubs.map((hub) => {
    const existing = existingHubs.get(hub.id)?.logoUrl;
    return [hub.id, typeof existing === "string" && existing.trim() ? existing : hub.logoSource];
  }));
}

async function writeCanonicalStructure(db, state, logoUrls, plan, backupPath) {
  const now = admin.firestore.Timestamp.now();
  const existingHubs = new Map(state.hubDocs.map((doc) => [doc.id, doc]));
  const existingRooms = new Map(state.roomDocs.map((doc) => [doc.id, doc]));
  const expectedInventory = inventoryOf(stateDocuments(state));

  return db.runTransaction(async (transaction) => {
    const actualDocuments = await transactionStateDocuments(transaction, state);
    const difference = compareInventories(expectedInventory, inventoryOf(actualDocuments));
    assert(
      difference.missing.length === 0 && difference.added.length === 0 && difference.changed.length === 0,
      `Production structure changed during validation: ${JSON.stringify(difference)}`,
    );
    const migrationDoc = await transaction.get(state.migrationRef);
    assert(!migrationDoc.exists, `Migration marker ${MIGRATION_ID} already exists`);

    let writes = 0;
    const update = (doc, data) => {
      transaction.update(doc.ref, data);
      writes += 1;
    };
    const create = (ref, data) => {
      transaction.create(ref, data);
      writes += 1;
    };
    const remove = (doc) => {
      transaction.delete(doc.ref);
      writes += 1;
    };

    update(state.orgDoc, {
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
    });

    for (const hub of hubs) {
      const hubRef = state.leagueRef.collection("hubs").doc(hub.id);
      const logoUrl = logoUrls.get(hub.id);
      const fields = {
        orgId: ORG_ID,
        leagueId: LEAGUE_ID,
        name: hub.name,
        location: hub.location,
        logoUrl,
        iconName: null,
      };
      const existingHub = existingHubs.get(hub.id);
      if (existingHub) update(existingHub, fields);
      else create(hubRef, { ...fields, createdAt: now });

      const roomRef = state.orgRef.collection("chatRooms").doc(`jphl_hub_room_${hub.slug.replaceAll("-", "_")}`);
      const roomFields = {
        orgId: ORG_ID,
        name: `${hub.name} - General`,
        type: "league",
        leagueId: LEAGUE_ID,
        hubId: hub.id,
        teamId: null,
        isArchived: false,
        roomIconName: null,
        roomImageUrl: logoUrl,
      };
      const existingRoom = existingRooms.get(roomRef.id);
      if (existingRoom) update(existingRoom, roomFields);
      else create(roomRef, {
        ...roomFields,
        participants: [],
        createdAt: now,
        lastMessage: null,
        lastMessageAt: now,
        lastMessageBy: null,
      });
    }

    for (const item of plan.items) {
      const targetRef = state.leagueRef.collection("hubs").doc(item.target.hubId)
        .collection("teams").doc(item.targetId);
      const logoUrl = logoUrls.get(item.target.hubId);
      const existingData = item.existing?.doc?.data() ?? {};
      const fields = {
        orgId: ORG_ID,
        leagueId: LEAGUE_ID,
        hubId: item.target.hubId,
        name: item.target.name,
        ageGroup: item.target.ageGroup,
        division: item.target.division,
        logoUrl,
        iconName: null,
        memberIds: Array.isArray(existingData.memberIds) ? existingData.memberIds : [],
        sourceTeamId: item.target.sourceId,
        sourceDivisionId: RAMP_DIVISION_IDS[item.target.ageGroup],
        sourceUrl: DIRECTORY_URL,
      };
      if (item.kind === "create") {
        create(targetRef, { ...fields, createdAt: now });
      } else if (item.kind === "move") {
        create(targetRef, { ...existingData, ...fields });
        remove(item.existing.doc);
      } else {
        update(item.existing.doc, fields);
      }
    }

    for (const retired of plan.retired) remove(retired.doc);
    for (const room of state.retiredRooms) {
      update(room, {
        isArchived: true,
        archivedAt: now,
        archivedBy: "reconcile-jphl-structure",
      });
    }
    for (const doc of [...state.userDocs, ...state.invitationDocs]) {
      const patch = assignmentPatch(doc.data(), plan);
      if (Object.keys(patch).length > 0) update(doc, patch);
    }
    if (state.dummyAnnouncement) remove(state.dummyAnnouncement);
    for (const doc of state.roomMessages) remove(doc);
    for (const doc of state.oldRooms) remove(doc);
    for (const doc of state.oldTeamDocs) remove(doc);
    for (const doc of state.oldHubDocs) remove(doc);

    create(state.migrationRef, {
      action: "reconcileJphlStructure",
      actorId: "system-production-migration",
      actorName: "Codex production migration",
      actorEmail: null,
      actorRole: "system",
      backupFile: path.basename(backupPath),
      request: {
        approvedPlan: "Reconcile the production structure to the exact official JPHL directory",
        sourceUrl: DIRECTORY_URL,
      },
      result: {
        expectedHubs: hubs.length,
        expectedTeams: desiredTeamEntries().length,
        archivedRetiredRooms: state.retiredRooms.length,
        removedDummyHubs: state.oldHubDocs.length,
        removedDummyTeams: state.oldTeamDocs.length,
        removedDummyRooms: state.oldRooms.length,
        updatedTeams: plan.items.filter((item) => item.kind === "update").length,
        movedTeams: plan.items.filter((item) => item.kind === "move").length,
        createdTeams: plan.items.filter((item) => item.kind === "create").length,
        retiredTeams: plan.retired.length,
      },
      createdAt: now,
    });

    assert(writes < 450, `Refusing oversized structure transaction with ${writes} writes`);
    return { writes };
  });
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
  assert(hubDocs.size === hubs.length, `Expected ${hubs.length} hubs, found ${hubDocs.size}`);
  assert(hubDocs.docs.every((doc) => canonicalHubIds.has(doc.id)), "Non-canonical hub remains after migration");

  const teamDocs = [];
  const logoUrls = [];
  for (const hubDoc of hubDocs.docs) {
    const teams = await hubDoc.ref.collection("teams").get();
    teamDocs.push(...teams.docs);
    assert(teams.docs.every((doc) => doc.data().hubId === hubDoc.id), `Team has incorrect hubId under ${hubDoc.id}`);
    assert(teams.docs.every((doc) => doc.data().logoUrl === hubDoc.data().logoUrl), `Team logo differs from hub logo under ${hubDoc.id}`);
    logoUrls.push(hubDoc.data().logoUrl);
  }
  const plan = buildTeamPlan(teamDocs.map((doc) => ({
    id: doc.id,
    hubId: doc.ref.parent.parent.id,
    name: doc.data().name,
    ageGroup: doc.data().ageGroup,
    sourceTeamId: doc.data().sourceTeamId,
    doc,
  })));
  assert(teamDocs.length === desiredTeamEntries().length, `Expected ${desiredTeamEntries().length} teams, found ${teamDocs.length}`);
  assert(plan.retired.length === 0, "A retired JPHL team remains after migration");
  assert(plan.items.every((item) => item.kind === "update"), "The reconciled JPHL structure is not idempotent");
  assert(plan.items.every((item) => item.existing.sourceTeamId === item.target.sourceId), "A team has stale RAMP routing after migration");
  assert(userDocs.docs.every((doc) => !hasAny(doc.data().hubIds, dummyHubIds) && !hasAny(doc.data().teamIds, dummyTeamIds)), "A user still references dummy structure");
  assert(invitationDocs.docs.every((doc) => !hasAny(doc.data().hubIds, dummyHubIds) && !hasAny(doc.data().teamIds, dummyTeamIds)), "An invitation still references dummy structure");
  assert(announcementDocs.docs.every((doc) => !dummyHubIds.has(doc.data().hubId)), "An announcement still targets dummy structure");

  const activeHubRooms = roomDocs.docs.filter((doc) => doc.data().leagueId === LEAGUE_ID && doc.data().hubId && doc.data().isArchived !== true);
  assert(activeHubRooms.length === hubs.length, `Expected ${hubs.length} active hub rooms, found ${activeHubRooms.length}`);
  assert(activeHubRooms.every((doc) => canonicalHubIds.has(doc.data().hubId)), "A dummy hub room remains");
  assert(activeHubRooms.every((doc) => doc.data().roomImageUrl === hubDocs.docs.find((hub) => hub.id === doc.data().hubId).data().logoUrl), "A hub room logo is out of sync");
  assert(roomDocs.docs.filter((doc) => approvedRetiredHubIds.has(doc.data().hubId)).every((doc) => doc.data().isArchived === true), "A retired hub room remains active");

  const checks = await Promise.all(logoUrls.map((url) => fetch(url, { method: "HEAD" })));
  assert(checks.every((response) => response.ok), `One or more Firebase logo URLs failed: ${checks.map((response) => response.status).join(", ")}`);
  return { hubs: hubDocs.size, teams: teamDocs.length, hubRooms: activeHubRooms.length, logoUrls: logoUrls.length };
}

async function main() {
  const app = admin.initializeApp({ projectId: PROJECT_ID }, "jphl-structure-reconciliation");
  const db = admin.firestore(app);
  db.settings({ ignoreUndefinedProperties: true });

  console.log(`Target project: ${PROJECT_ID}`);
  if (RESTORE_PATH) {
    await restoreBackup(db, RESTORE_PATH);
    return;
  }
  const [state, logos] = await Promise.all([loadState(db), validateOfficialSource()]);
  const plan = buildTeamPlan(state.teamDocs
    .filter((doc) => !dummyHubIds.has(doc.ref.parent.parent.id))
    .map((doc) => ({
      id: doc.id,
      hubId: doc.ref.parent.parent.id,
      name: doc.data().name,
      ageGroup: doc.data().ageGroup,
      sourceTeamId: doc.data().sourceTeamId,
      doc,
    })));
  const plannedTeamIds = new Set(plan.items.map((item) => item.targetId));
  for (const doc of [...state.userDocs, ...state.invitationDocs]) {
    const data = { ...doc.data(), ...assignmentPatch(doc.data(), plan) };
    const unknownTeamIds = (data.teamIds || []).filter((teamId) => !plannedTeamIds.has(teamId));
    assert(unknownTeamIds.length === 0, `${doc.ref.path} references unknown teams: ${unknownTeamIds.join(", ")}`);
  }
  printPlan(state, logos, plan);
  if (!APPLY) {
    console.log("Dry run passed. Re-run with --apply to back up and reconcile production.");
    return;
  }

  assert(!state.migrationDoc.exists, `Migration marker ${MIGRATION_ID} already exists`);
  const backupPath = writeBackup(state, plan);
  console.log(`Backup written: ${backupPath}`);
  const logoUrls = resolveLogoUrls(state);
  const writeResult = await writeCanonicalStructure(db, state, logoUrls, plan, backupPath);
  await finalizeBackup(db, backupPath);
  console.log("Backup finalized with post-migration concurrency guards");
  const verification = await verify(db);
  console.log(`Verification passed: ${JSON.stringify({ ...verification, atomicWrites: writeResult.writes })}`);
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
  assignmentPatch,
  buildTeamPlan,
  compareInventories,
  finalizeBackup,
  hubs,
  loadState,
  plannedCreatedPaths,
  resolveLogoUrls,
  teamKey,
  writeBackup,
  writeCanonicalStructure,
};
