#!/usr/bin/env node

const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");
const {randomUUID} = require("crypto");
const path = require("path");

const PROJECT_ID = "jdb-league-hub";
const ORG_ID = "store_review_league";
const LEAGUE_ID = "store_review_hockey";
const HUB_ID = "store_review_north_hub";
const TEAM_ID = "store_review_north_stars_u15";
const OPPONENT_HUB_ID = "store_review_west_hub";
const OPPONENT_TEAM_ID = "store_review_west_wolves_u15";
const REVIEW_EMAIL = "appreview@jdbuilds.ca";
const REVIEW_DISPLAY_NAME = "Alex Morgan";

function requireReviewPassword() {
  const password = process.env.LEAGUE_HUB_REVIEW_PASSWORD;
  if (!password || password.length < 16) {
    throw new Error("LEAGUE_HUB_REVIEW_PASSWORD must be set to a password of at least 16 characters.");
  }
  return password;
}

async function firebaseAccessToken() {
  const auth = new GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
    ],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("Unable to obtain Firebase access token.");
  return token.token;
}

async function ensureReviewAuthUser(password) {
  const token = await firebaseAccessToken();
  const queryResponse = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:query`,
    {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "X-Goog-User-Project": PROJECT_ID, "Content-Type": "application/json"},
      body: JSON.stringify({email: [REVIEW_EMAIL]}),
    },
  );
  if (!queryResponse.ok) {
    throw new Error(`Unable to look up reviewer Auth user: ${queryResponse.status} ${await queryResponse.text()}`);
  }
  const existing = (await queryResponse.json()).userInfo?.[0];
  const endpoint = existing ? "accounts:update" : "accounts";
  const payload = existing ? {
    localId: existing.localId,
    email: REVIEW_EMAIL,
    password,
    displayName: REVIEW_DISPLAY_NAME,
    emailVerified: true,
    disabled: false,
  } : {
    email: REVIEW_EMAIL,
    password,
    displayName: REVIEW_DISPLAY_NAME,
    emailVerified: true,
    disabled: false,
  };
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/${endpoint}`,
    {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "X-Goog-User-Project": PROJECT_ID, "Content-Type": "application/json"},
      body: JSON.stringify(payload),
    },
  );
  if (!response.ok) {
    throw new Error(`Unable to create/update reviewer Auth user: ${response.status} ${await response.text()}`);
  }
  return (await response.json()).localId;
}

function isoDate(date) {
  return date.toISOString();
}

function startAt(daysFromNow, hour) {
  const result = new Date();
  result.setUTCDate(result.getUTCDate() + daysFromNow);
  result.setUTCHours(hour, 0, 0, 0);
  return result;
}

function localDate(date) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Edmonton",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date).filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return {date: `${parts.year}-${parts.month}-${parts.day}`, time: `${parts.hour}:${parts.minute}`};
}

function gameData(id, first, second, firstId, secondId, firstHubId, secondHubId, startsAt, status = "scheduled", scores = null) {
  const endsAt = new Date(startsAt.getTime() + 2 * 60 * 60 * 1000);
  const start = localDate(startsAt);
  const end = localDate(endsAt);
  return {
    source: "store-review-fixture",
    sourceSeasonId: "review-2026",
    sourceUid: `${id}@review.leaguehub.ca`,
    previousSourceUids: [],
    firstTeamId: firstId,
    secondTeamId: secondId,
    teamIds: [firstId, secondId],
    hubIds: [firstHubId, secondHubId],
    leagueIds: [LEAGUE_ID],
    division: "U15 AAA",
    title: `${first} vs ${second}`,
    firstTeamName: first,
    secondTeamName: second,
    startsAt,
    endsAt,
    timezone: "America/Edmonton",
    localDate: start.date,
    localStartTime: start.time,
    localEndTime: end.time,
    location: "League Hub Community Arena, Calgary",
    description: "Store review fixture demonstrating League Hub schedules and game details.",
    status,
    firstScore: scores?.[0] ?? null,
    secondScore: scores?.[1] ?? null,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

async function main() {
  if (process.env.GOOGLE_CLOUD_PROJECT && process.env.GOOGLE_CLOUD_PROJECT !== PROJECT_ID) {
    throw new Error(`GOOGLE_CLOUD_PROJECT must be ${PROJECT_ID}.`);
  }
  const password = requireReviewPassword();
  const reviewerId = await ensureReviewAuthUser(password);

  admin.initializeApp({projectId: PROJECT_ID, storageBucket: "jdb-league-hub.firebasestorage.app"});
  const db = admin.firestore();
  db.settings({ignoreUndefinedProperties: true});
  const orgRef = db.collection("organizations").doc(ORG_ID);
  const leagueRef = orgRef.collection("leagues").doc(LEAGUE_ID);
  await db.recursiveDelete(orgRef);

  const now = new Date();
  const nowIso = isoDate(now);
  const logo = "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Northstar%20Hockey%20Academy%20-%20PNG.png";
  const opponentLogo = "https://cloud3.rampinteractive.com/juniorprospectshockeyleague/files/Wolves%20HC%20-%20PNG.png";

  await orgRef.set({
    id: ORG_ID,
    name: "League Hub Review League",
    ownerId: reviewerId,
    logoUrl: null,
    primaryColor: "#06182C",
    secondaryColor: "#0B4D7A",
    accentColor: "#64E0DC",
    createdAt: nowIso,
    purpose: "app-store-review",
  });
  await leagueRef.set({
    id: LEAGUE_ID,
    orgId: ORG_ID,
    name: "League Hub Review Hockey League",
    abbreviation: "LHRHL",
    description: "A safe, isolated demonstration league for App Store and Google Play review.",
    logoUrl: null,
    iconName: "trophy",
    websiteUrl: "https://leaguehub.ca",
    instagramUrl: "https://www.instagram.com/leaguehubapp",
    xUrl: "https://x.com/leaguehubapp",
    createdAt: nowIso,
  });

  const northHubRef = leagueRef.collection("hubs").doc(HUB_ID);
  const westHubRef = leagueRef.collection("hubs").doc(OPPONENT_HUB_ID);
  await Promise.all([
    northHubRef.set({id: HUB_ID, orgId: ORG_ID, leagueId: LEAGUE_ID, name: "North Stars Hockey", location: "Calgary, Alberta", logoUrl: logo, iconName: "groups", createdAt: nowIso}),
    westHubRef.set({id: OPPONENT_HUB_ID, orgId: ORG_ID, leagueId: LEAGUE_ID, name: "West Wolves Hockey", location: "Cochrane, Alberta", logoUrl: opponentLogo, iconName: "groups", createdAt: nowIso}),
  ]);
  await Promise.all([
    northHubRef.collection("teams").doc(TEAM_ID).set({id: TEAM_ID, orgId: ORG_ID, leagueId: LEAGUE_ID, hubId: HUB_ID, name: "U15 AAA - North Stars", ageGroup: "U15", division: "AAA", logoUrl: logo, iconName: "groups", memberIds: [reviewerId], chatRoomId: "review_team_room", createdAt: nowIso}),
    westHubRef.collection("teams").doc(OPPONENT_TEAM_ID).set({id: OPPONENT_TEAM_ID, orgId: ORG_ID, leagueId: LEAGUE_ID, hubId: OPPONENT_HUB_ID, name: "U15 AAA - West Wolves", ageGroup: "U15", division: "AAA", logoUrl: opponentLogo, iconName: "groups", memberIds: [], createdAt: nowIso}),
  ]);

  await db.collection("users").doc(reviewerId).set({
    id: reviewerId,
    email: REVIEW_EMAIL,
    displayName: REVIEW_DISPLAY_NAME,
    title: "Team Coordinator",
    role: "staff",
    orgId: ORG_ID,
    hubIds: [HUB_ID],
    leagueIds: [LEAGUE_ID],
    teamIds: [TEAM_ID],
    createdAt: nowIso,
    isActive: true,
    blockedUserIds: [],
    hasAcceptedCommunityGuidelines: true,
    purpose: "app-store-review",
  });

  const users = [
    ["review_coach", "Jamie Chen", "Head Coach", "coach@review.leaguehub.ca"],
    ["review_manager", "Morgan Lee", "League Manager", "manager@review.leaguehub.ca"],
    ["review_trainer", "Taylor Brooks", "Athletic Therapist", "trainer@review.leaguehub.ca"],
  ];
  for (const [id, displayName, title, email] of users) {
    await db.collection("users").doc(id).set({id, email, displayName, title, role: id === "review_manager" ? "managerAdmin" : "staff", orgId: ORG_ID, hubIds: [HUB_ID], leagueIds: [LEAGUE_ID], teamIds: [TEAM_ID], createdAt: nowIso, isActive: true, blockedUserIds: [], hasAcceptedCommunityGuidelines: true, purpose: "app-store-review"});
  }
  await northHubRef.collection("teams").doc(TEAM_ID).update({memberIds: [reviewerId, ...users.map(([id]) => id)]});

  const announcements = [
    ["review_announcement_game_day", "Game day arrival details", "Players should arrive 60 minutes before puck drop. Please use the north entrance and check in with your team coordinator.", true, -1],
    ["review_announcement_equipment", "Equipment check this week", "Coaches will complete the mid-season equipment check after Thursday’s ice time.", true, -4],
    ["review_announcement_volunteers", "Tournament volunteers", "Thank you to everyone who signed up. Final assignments are now available in the team chat.", false, -8],
  ];
  for (const [id, title, body, isPinned, days] of announcements) {
    const date = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    await orgRef.collection("announcements").doc(id).set({id, orgId: ORG_ID, scope: "team", leagueId: LEAGUE_ID, hubId: HUB_ID, teamId: TEAM_ID, title, body, authorId: "review_manager", authorName: "Morgan Lee", authorRole: "League Manager", attachments: [], isPinned, createdAt: date});
  }

  const rooms = [
    ["review_team_room", "North Stars Team Chat", "league", TEAM_ID, "Practice jerseys are ready for pickup.", "Jamie Chen", -0.1],
    ["review_league_room", "Review League - General", "league", null, "Welcome to the League Hub review league.", "Morgan Lee", -1],
    ["review_tournament_room", "Fall Showcase", "event", TEAM_ID, "The schedule and venue map are posted.", "Morgan Lee", -2],
  ];
  for (const [id, name, type, teamId, lastMessage, lastMessageBy, days] of rooms) {
    const activity = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    const roomRef = orgRef.collection("chatRooms").doc(id);
    await roomRef.set({id, orgId: ORG_ID, name, type, leagueId: LEAGUE_ID, hubId: HUB_ID, teamId, participants: [], createdAt: nowIso, isArchived: false, lastMessage, lastMessageAt: activity, lastMessageBy, roomIconName: type === "event" ? "event" : "groups", roomImageUrl: logo, participantNames: {}});
    const messages = [
      ["Morgan Lee", "review_manager", "Welcome! This review space shows how a league keeps everyone connected."],
      ["Jamie Chen", "review_coach", lastMessage],
    ];
    for (let index = 0; index < messages.length; index++) {
      const [senderName, senderId, text] = messages[index];
      await roomRef.collection("messages").doc(`message_${index + 1}`).set({chatRoomId: id, senderId, senderName, text, createdAt: new Date(activity.getTime() - (messages.length - index) * 60 * 60 * 1000), readBy: [senderId], deleted: false});
    }
  }

  const upcoming = startAt(6, 1);
  const later = startAt(13, 2);
  const final = startAt(-8, 1);
  await Promise.all([
    orgRef.collection("scheduleEvents").doc("review_upcoming_game").set(gameData("review-upcoming", "U15 AAA - North Stars", "U15 AAA - West Wolves", TEAM_ID, OPPONENT_TEAM_ID, HUB_ID, OPPONENT_HUB_ID, upcoming)),
    orgRef.collection("scheduleEvents").doc("review_later_game").set(gameData("review-later", "U15 AAA - West Wolves", "U15 AAA - North Stars", OPPONENT_TEAM_ID, TEAM_ID, OPPONENT_HUB_ID, HUB_ID, later)),
    orgRef.collection("scheduleEvents").doc("review_final_game").set(gameData("review-final", "U15 AAA - North Stars", "U15 AAA - West Wolves", TEAM_ID, OPPONENT_TEAM_ID, HUB_ID, OPPONENT_HUB_ID, final, "final", [4, 2])),
  ]);

  const bucket = admin.storage().bucket();
  const policyPath = `organizations/${ORG_ID}/policies/review_code_of_conduct/league-hub-review-code-of-conduct.pdf`;
  const policySource = path.resolve(
    __dirname,
    "league-hub-review-code-of-conduct.pdf",
  );
  const downloadToken = randomUUID();
  await bucket.upload(policySource, {destination: policyPath, metadata: {contentType: "application/pdf", cacheControl: "private, max-age=3600", metadata: {firebaseStorageDownloadTokens: downloadToken}}});
  const policyUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(policyPath)}?alt=media&token=${downloadToken}`;
  await orgRef.collection("policies").doc("review_code_of_conduct").set({
    id: "review_code_of_conduct", orgId: ORG_ID, leagueId: LEAGUE_ID, hubId: HUB_ID, teamId: TEAM_ID,
    name: "Game Day Code of Conduct", fileUrl: policyUrl, fileType: "pdf", fileSize: 0, category: "Code of Conduct",
    uploadedBy: "review_manager", uploadedByName: "Morgan Lee",
    versions: [{url: policyUrl, version: 1, uploadedAt: nowIso, uploadedBy: "review_manager", uploadedByName: "Morgan Lee", fileSize: 0}],
    createdAt: nowIso, updatedAt: nowIso,
  });

  const verification = {
    reviewerId,
    org: (await orgRef.get()).data()?.name,
    leagues: (await orgRef.collection("leagues").get()).size,
    users: (await db.collection("users").where("orgId", "==", ORG_ID).get()).size,
    announcements: (await orgRef.collection("announcements").get()).size,
    chatRooms: (await orgRef.collection("chatRooms").get()).size,
    scheduleEvents: (await orgRef.collection("scheduleEvents").get()).size,
    policies: (await orgRef.collection("policies").get()).size,
  };
  console.log(JSON.stringify(verification, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
