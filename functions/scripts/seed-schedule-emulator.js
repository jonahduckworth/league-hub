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
const JPHL_LOGO_URLS = Object.freeze({
  "Bellingham HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Bellingham HC Logo - White.png",
  "Bow Valley HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Bow%20Valley%20Circle%20Badge.png",
  "Calgary Rockies": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Calgary%20Rockies.png",
  "Calgary Stallions": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Calgary%20Stallions.png",
  "Coquitlam HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Coquitlam%20HC%20PNG.png",
  "Cowichan Jr Capitals": "https://cloud.rampinteractive.com/juniorprospectshockeyleague/files/JR-CAPITALS-Logo.png",
  "Epic Hockey Academy": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/EPIC-E-icon-full-colour-no-background.png",
  "HC Edmonton": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/EHC.png",
  "Island HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Island%20Hockey%20Club%20png.png",
  "Kootenay HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Kootenay%20Hockey%20Academy%20Text%20Only%20-%20PNG.png",
  "Langley HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Langley.png",
  "Lethbridge United": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Lethbridge%20United.png",
  "Lloydminster Athletics": "https://cloud3.rampinteractive.com/juniorprospectshockeyleagueimages/team-logos/4e434092-bd0b-410e-b092-ab059cab8427_Lloydminster%20Athletics.png",
  "Northstars HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Northstar%20Hockey%20Academy%20-%20PNG.png",
  "Okanagan HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Okanagan%20HC%20Logo%20-%20OFFICIAL.png",
  "South Sask HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/team/319121/16839aad-a9c3-452b-b490-ab0f2cbe31e0.png",
  "Surrey Eagles HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/SE_ACADEMEY_LOGO.png",
  "Titans Hockey Union": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Logo%20PNGs/Titans%20Hockey%20Union.png",
  "Velocity HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/Colour Logo_on blk@2x.png",
  "Victoria HA": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Victoria%20HC%20On%20White%20-%20PNG.png",
  "Wolves HC": "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Wolves%20HC%20-%20PNG.png",
});

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
  const legacyMatch = team.name.match(/^(\d{2}U)\s+AAA\s+-\s+(.+)$/i);
  const ageGroup = team.ageGroup ?? legacyMatch?.[1]?.toUpperCase();
  const hubName = (legacyMatch?.[2] ?? team.name).trim();
  if (!ageGroup || !hubName) throw new Error(`Unexpected JPHL team route: ${team.name}`);
  return { ...team, name: `${ageGroup} AAA - ${hubName}`, ageGroup, hubName };
}

function logoUrlForHub(hubName) {
  const normalized = slug(hubName);
  const match = Object.entries(JPHL_LOGO_URLS).find(([name]) => slug(name) === normalized);
  return match?.[1] ?? null;
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
  const hubsWithoutLogos = [...hubIds.keys()].filter((hubName) => logoUrlForHub(hubName) == null);
  if (hubsWithoutLogos.length > 0) {
    console.warn(`Using initials for hubs without a published logo fixture: ${hubsWithoutLogos.join(", ")}`);
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
      logoUrl: logoUrlForHub(hubName),
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
      logoUrl: logoUrlForHub(team.hubName),
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

async function seedUpcomingPreview(db, teams, seasonId) {
  const orderedTeams = [...teams].sort((first, second) =>
    first.ageGroup.localeCompare(second.ageGroup) || first.hubName.localeCompare(second.hubName));
  const first = orderedTeams.find((team) =>
    team.ageGroup === "17U" && team.hubName === "Wolves HC") ?? orderedTeams[0];
  const sameDivision = orderedTeams.filter((team) =>
    team.ageGroup === first?.ageGroup && team.hubName !== first.hubName);
  const second = sameDivision.find((team) => team.hubName === "Calgary Rockies") ?? sameDivision[0];
  if (!first || !second) {
    throw new Error("The current JPHL directory needs two teams in one division for the preview game.");
  }

  const startsAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  startsAt.setUTCMinutes(0, 0, 0);
  const endsAt = new Date(startsAt.getTime() + 2 * 60 * 60 * 1000);
  const localParts = (date) => Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Edmonton",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(date).filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );
  const start = localParts(startsAt);
  const end = localParts(endsAt);
  const firstTeamId = `emulator_team_${first.teamId}`;
  const secondTeamId = `emulator_team_${second.teamId}`;
  const firstHubId = `emulator_hub_${slug(first.hubName)}`;
  const secondHubId = `emulator_hub_${slug(second.hubName)}`;

  await db.collection("organizations").doc(ORG_ID)
    .collection("scheduleEvents").doc("emulator_preview_upcoming_game").set({
      source: "emulator-preview",
      sourceSeasonId: seasonId,
      sourceUid: "emulator-preview-upcoming@leaguehub.local",
      previousSourceUids: [],
      firstTeamId,
      secondTeamId,
      teamIds: [firstTeamId, secondTeamId],
      hubIds: [firstHubId, secondHubId],
      leagueIds: [LEAGUE_ID],
      division: `${first.ageGroup} AAA`,
      title: `${first.name} vs ${second.name}`,
      firstTeamName: first.name,
      secondTeamName: second.name,
      startsAt,
      endsAt,
      timezone: "America/Edmonton",
      localDate: `${start.year}-${start.month}-${start.day}`,
      localStartTime: `${start.hour}:${start.minute}`,
      localEndTime: `${end.hour}:${end.minute}`,
      location: "Great Plains Recreation Facility, Calgary",
      description: "Local emulator preview game for UI testing.",
      status: "scheduled",
      firstScore: null,
      secondScore: null,
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
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
  if (discovered.length === 0) throw new Error("The current JPHL directory exposed no teams.");

  await ensureAuthUser(auth);
  await seedStructure(db, discovered, seasons[0]);
  const { synchronizeOrganizationSchedule } = require("../lib/schedule/rampSync");
  const result = await synchronizeOrganizationSchedule(ORG_ID);
  await seedUpcomingPreview(db, discovered, seasons[0]);
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
