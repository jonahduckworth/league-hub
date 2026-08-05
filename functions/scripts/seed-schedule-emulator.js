#!/usr/bin/env node

const admin = require("firebase-admin");
const { parseRampDirectory } = require("../lib/schedule/rampDiscovery");

const PROJECT_ID = "jdb-league-hub";
const ORG_ID = "emulator_jphl";
const LEAGUE_ID = "emulator_jphl_league";
const USER_ID = "emulator_schedule_admin";
const USER_EMAIL = "simulator@leaguehub.local";
const USER_PASSWORD = "LeagueHub123!";
const JPHL_URL = "https://juniorprospectshockeyleague.com";

function assertLocalEmulator(name, value, expectedPort) {
  if (!value) throw new Error(`${name} must be set before this script can run.`);
  const url = new URL(`http://${value}`);
  const localHosts = new Set(["127.0.0.1", "localhost", "::1", "[::1]"]);
  if (!localHosts.has(url.hostname) || url.port !== expectedPort) {
    throw new Error(`${name} must target a local emulator on port ${expectedPort}; received ${value}.`);
  }
}

function slug(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
}

function teamDetails(team) {
  const match = team.name.match(/^(\d{2}U)\s+AAA\s+-\s+(.+)$/i);
  if (!match) throw new Error(`Unexpected JPHL team name: ${team.name}`);
  return { ...team, ageGroup: match[1].toUpperCase(), hubName: match[2].trim() };
}

async function ensureAuthUser(auth) {
  try {
    await auth.updateUser(USER_ID, {
      email: USER_EMAIL,
      password: USER_PASSWORD,
      displayName: "Schedule Simulator",
      disabled: false,
    });
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid: USER_ID,
      email: USER_EMAIL,
      password: USER_PASSWORD,
      displayName: "Schedule Simulator",
      emailVerified: true,
    });
  }
}

async function seedStructure(db, teams, seasonId) {
  const now = new Date().toISOString();
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  await db.recursiveDelete(orgRef);

  const hubIds = new Map();
  for (const team of teams) {
    if (!hubIds.has(team.hubName)) hubIds.set(team.hubName, `emulator_hub_${slug(team.hubName)}`);
  }
  const teamIds = teams.map((team) => `emulator_team_${team.teamId}`);
  const divisionIds = Object.fromEntries(teams.map((team) => [team.ageGroup, team.divisionId]));

  await orgRef.set({
    name: "JPHL Schedule Simulator",
    ownerId: USER_ID,
    primaryColor: "#1A3A5C",
    secondaryColor: "#2E75B6",
    accentColor: "#4DA3FF",
    createdAt: now,
    scheduleIntegration: {
      provider: "ramp",
      enabled: true,
      autoDiscoverSeason: true,
      baseUrl: JPHL_URL,
      associationId: "2888",
      seasonId,
      legacySourceSeasonId: seasonId,
      timezone: "America/Edmonton",
      divisionIds,
      updatedAt: now,
      updatedBy: "schedule-emulator-seed",
    },
  });
  await leagueRef.set({
    orgId: ORG_ID,
    name: "Junior Prospects Hockey League",
    abbreviation: "JPHL",
    description: "Local emulator data from the public JPHL schedule.",
    logoUrl: null,
    iconName: "trophy",
    websiteUrl: JPHL_URL,
    createdAt: now,
  });

  let batch = db.batch();
  let pending = 0;
  const commit = async () => {
    if (pending === 0) return;
    await batch.commit();
    batch = db.batch();
    pending = 0;
  };
  const set = async (reference, data) => {
    batch.set(reference, data);
    pending++;
    if (pending >= 400) await commit();
  };

  for (const [hubName, hubId] of hubIds) {
    await set(leagueRef.collection("hubs").doc(hubId), {
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      name: hubName,
      location: null,
      logoUrl: null,
      iconName: "groups",
      createdAt: now,
    });
  }
  for (const team of teams) {
    const hubId = hubIds.get(team.hubName);
    const teamId = `emulator_team_${team.teamId}`;
    await set(leagueRef.collection("hubs").doc(hubId).collection("teams").doc(teamId), {
      orgId: ORG_ID,
      leagueId: LEAGUE_ID,
      hubId,
      name: team.name,
      ageGroup: team.ageGroup,
      division: "AAA",
      logoUrl: null,
      iconName: "groups",
      memberIds: [USER_ID],
      sourceTeamId: team.teamId,
      sourceDivisionId: team.divisionId,
      createdAt: now,
    });
  }
  await commit();

  await db.collection("users").doc(USER_ID).set({
    id: USER_ID,
    email: USER_EMAIL,
    displayName: "Schedule Simulator",
    title: "Local QA Admin",
    avatarUrl: null,
    role: "superAdmin",
    orgId: ORG_ID,
    hubIds: [...hubIds.values()],
    leagueIds: [LEAGUE_ID],
    teamIds,
    createdAt: now,
    isActive: true,
  });
}

async function main() {
  assertLocalEmulator("FIRESTORE_EMULATOR_HOST", process.env.FIRESTORE_EMULATOR_HOST, "8081");
  assertLocalEmulator("FIREBASE_AUTH_EMULATOR_HOST", process.env.FIREBASE_AUTH_EMULATOR_HOST, "9099");
  if ((process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT) !== PROJECT_ID) {
    throw new Error(`GCLOUD_PROJECT must be ${PROJECT_ID} for the simulator client namespace.`);
  }

  admin.initializeApp({ projectId: PROJECT_ID });
  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  const auth = admin.auth();

  const response = await fetch(JPHL_URL, { headers: { "User-Agent": "LeagueHub-EmulatorSeed/1.0" } });
  if (!response.ok) throw new Error(`JPHL directory returned HTTP ${response.status}.`);
  const discovered = parseRampDirectory(await response.text()).map(teamDetails);
  const seasons = [...new Set(discovered.map((team) => team.seasonId))];
  if (seasons.length !== 1) {
    throw new Error(`Expected one current JPHL season; found ${seasons.join(", ") || "none"}.`);
  }
  if (discovered.length !== 48) {
    throw new Error(`Expected 48 current JPHL teams; found ${discovered.length}.`);
  }

  await ensureAuthUser(auth);
  await seedStructure(db, discovered, seasons[0]);
  const { synchronizeOrganizationSchedule } = require("../lib/schedule/rampSync");
  const result = await synchronizeOrganizationSchedule(ORG_ID);
  const eventCount = await db.collection("organizations").doc(ORG_ID)
    .collection("scheduleEvents").where("isActive", "==", true).count().get();

  console.log(JSON.stringify({
    emulatorOnly: true,
    organizationId: ORG_ID,
    seasonId: result.sourceSeasonId,
    discovery: result.seasonDiscoveryStatus,
    teamFeeds: `${result.teamFeedsSucceeded}/${result.teamFeedsTotal}`,
    games: eventCount.data().count,
    results: result,
    login: { email: USER_EMAIL, password: USER_PASSWORD },
  }, null, 2));
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
