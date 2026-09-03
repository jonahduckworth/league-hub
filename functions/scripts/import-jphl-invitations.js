#!/usr/bin/env node

/*
 * Validates and atomically creates a pre-reviewed JPHL invitation manifest.
 *
 * Dry run (default):
 *   node scripts/import-jphl-invitations.js --manifest /absolute/path/manifest.json
 *
 * Apply requires all three independent confirmations printed by the dry run:
 *   node scripts/import-jphl-invitations.js \
 *     --manifest /absolute/path/manifest.json \
 *     --apply \
 *     --confirm-import-id jphl-contacts-2026-27 \
 *     --expected-create-count 130 \
 *     --confirm-manifest-sha256 <sha256>
 */

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

const EXPECTED_PROJECT_ID = "jdb-league-hub";
const MAX_TITLE_LENGTH = 120;
const INVITATION_LIFETIME_MS = 7 * 24 * 60 * 60 * 1000;
const SYSTEM_ACTOR_ID = "system-jphl-contact-import";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function normalizeEmail(value) {
  assert(typeof value === "string", "Every invitation requires an email string");
  const email = value.trim().toLowerCase();
  assert(
    email.length > 0 && email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),
    `Invalid invitation email: ${email || "[blank]"}`,
  );
  return email;
}

function requiredString(value, label) {
  assert(typeof value === "string" && value.trim().length > 0, `${label} is required`);
  return value.trim();
}

function sortedUniqueStrings(value, label) {
  assert(Array.isArray(value), `${label} must be an array`);
  const strings = value.map((item, index) => requiredString(item, `${label}[${index}]`));
  return [...new Set(strings)].sort();
}

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function manifestSha256(manifest) {
  return crypto.createHash("sha256").update(canonicalJson(manifest)).digest("hex");
}

function invitationDocumentId(importId, email) {
  const digest = crypto.createHash("sha256")
    .update(`${importId}:${email}`)
    .digest("hex")
    .slice(0, 32);
  return `bulk_${digest}`;
}

function markerDocumentId(importId) {
  assert(/^[a-z0-9][a-z0-9-]{2,80}$/.test(importId), "importId must be a safe lowercase slug");
  return `bulk-invitations-${importId}`;
}

function validateManifest(manifest) {
  assert(manifest && typeof manifest === "object" && !Array.isArray(manifest), "Manifest must be an object");
  assert(manifest.version === 1, "Manifest version must be 1");
  assert(manifest.projectId === EXPECTED_PROJECT_ID, `Manifest projectId must be ${EXPECTED_PROJECT_ID}`);
  const importId = requiredString(manifest.importId, "importId");
  markerDocumentId(importId);
  const orgId = requiredString(manifest.orgId, "orgId");
  const orgName = requiredString(manifest.orgName, "orgName");
  const leagueId = requiredString(manifest.leagueId, "leagueId");
  const leagueName = requiredString(manifest.leagueName, "leagueName");
  assert(manifest.expected && typeof manifest.expected === "object", "expected summary is required");
  for (const key of [
    "sourceRows",
    "skippedMissingEmail",
    "skippedExistingUsers",
    "consolidatedDuplicateRows",
    "inviteCount",
    "hubCount",
    "teamCount",
    "leagueWideCount",
    "hubOnlyCount",
    "teamScopedCount",
  ]) {
    assert(Number.isInteger(manifest.expected[key]) && manifest.expected[key] >= 0, `expected.${key} must be a non-negative integer`);
  }
  assert(Array.isArray(manifest.invitations), "invitations must be an array");
  assert(
    manifest.invitations.length === manifest.expected.inviteCount,
    `Manifest contains ${manifest.invitations.length} invitations, expected ${manifest.expected.inviteCount}`,
  );

  const emails = new Set();
  const invitations = manifest.invitations.map((item, index) => {
    assert(item && typeof item === "object" && !Array.isArray(item), `invitations[${index}] must be an object`);
    const email = normalizeEmail(item.email);
    assert(!emails.has(email), `Duplicate invitation email: ${email}`);
    emails.add(email);
    const displayName = requiredString(item.displayName, `invitations[${index}].displayName`);
    const title = requiredString(item.title, `invitations[${index}].title`);
    assert(title.length <= MAX_TITLE_LENGTH, `Title is longer than ${MAX_TITLE_LENGTH} characters for ${email}`);
    assert(item.role === "staff", `Only staff invitations are allowed in this import: ${email}`);
    assert(Array.isArray(item.assignments) && item.assignments.length > 0, `Assignments are required for ${email}`);
    const assignments = item.assignments.map((assignment, assignmentIndex) => {
      assert(assignment && typeof assignment === "object", `Invalid assignment for ${email}`);
      return {
        hubName: requiredString(
          assignment.hubName,
          `invitations[${index}].assignments[${assignmentIndex}].hubName`,
        ),
        ageGroups: sortedUniqueStrings(
          assignment.ageGroups ?? [],
          `invitations[${index}].assignments[${assignmentIndex}].ageGroups`,
        ).map((value) => value.toUpperCase()),
      };
    });
    const hubNames = assignments.map((assignment) => assignment.hubName);
    assert(new Set(hubNames).size === hubNames.length, `Duplicate hub assignment for ${email}`);
    const sourceRows = [...new Set((item.sourceRows ?? []).map((row) => Number(row)))].sort((a, b) => a - b);
    assert(sourceRows.length > 0 && sourceRows.every(Number.isInteger), `Source rows are required for ${email}`);
    return {email, displayName, title, role: "staff", assignments, sourceRows};
  });

  return {
    version: 1,
    importId,
    projectId: EXPECTED_PROJECT_ID,
    orgId,
    orgName,
    leagueId,
    leagueName,
    source: manifest.source ?? null,
    expected: {...manifest.expected},
    invitations,
  };
}

function buildImportPlan(manifest, state) {
  const validated = validateManifest(manifest);
  assert(state.projectId === EXPECTED_PROJECT_ID, `Connected project must be ${EXPECTED_PROJECT_ID}`);
  assert(state.org && state.org.id === validated.orgId, `Organization ${validated.orgId} does not exist`);
  assert(state.org.name === validated.orgName, `Expected organization ${validated.orgName}, found ${state.org.name}`);
  assert(state.league && state.league.id === validated.leagueId, `League ${validated.leagueId} does not exist`);
  assert(state.league.name === validated.leagueName, `Unexpected league name: ${state.league.name}`);
  assert(state.hubs.length === validated.expected.hubCount, `Expected ${validated.expected.hubCount} hubs, found ${state.hubs.length}`);
  assert(state.teams.length === validated.expected.teamCount, `Expected ${validated.expected.teamCount} teams, found ${state.teams.length}`);
  assert(!state.markerExists, `Import marker ${markerDocumentId(validated.importId)} already exists`);

  const hubsByName = new Map();
  for (const hub of state.hubs) {
    assert(!hubsByName.has(hub.name), `Duplicate live hub name: ${hub.name}`);
    hubsByName.set(hub.name, hub);
  }
  const teamsByHubAndAge = new Map();
  for (const team of state.teams) {
    const ageGroup = requiredString(team.ageGroup, `Team ${team.id} ageGroup`).toUpperCase();
    const key = `${team.hubId}:${ageGroup}`;
    assert(!teamsByHubAndAge.has(key), `Duplicate live team assignment: ${key}`);
    teamsByHubAndAge.set(key, team);
  }
  const existingUserEmails = new Set(state.users.map((user) => normalizeEmail(user.email)));
  const pendingInvitationEmails = new Set(state.invitations
    .filter((invitation) => invitation.status === "pending")
    .map((invitation) => normalizeEmail(invitation.email)));
  const existingInvitationIds = new Set(state.invitations.map((invitation) => invitation.id));

  const invitations = validated.invitations.map((invitation) => {
    assert(!existingUserEmails.has(invitation.email), `Refusing to invite existing user: ${invitation.email}`);
    assert(!pendingInvitationEmails.has(invitation.email), `Pending invitation already exists: ${invitation.email}`);
    const hubIds = [];
    const teamIds = [];
    for (const assignment of invitation.assignments) {
      const hub = hubsByName.get(assignment.hubName);
      assert(hub, `Unknown live hub ${assignment.hubName} for ${invitation.email}`);
      hubIds.push(hub.id);
      for (const ageGroup of assignment.ageGroups) {
        const team = teamsByHubAndAge.get(`${hub.id}:${ageGroup}`);
        assert(team, `Unknown ${ageGroup} team in ${assignment.hubName} for ${invitation.email}`);
        teamIds.push(team.id);
      }
    }
    const id = invitationDocumentId(validated.importId, invitation.email);
    assert(!existingInvitationIds.has(id), `Import invitation document already exists: ${id}`);
    return {
      ...invitation,
      id,
      leagueIds: [validated.leagueId],
      hubIds: [...new Set(hubIds)].sort(),
      teamIds: [...new Set(teamIds)].sort(),
    };
  });
  assert(
    invitations.length === validated.expected.inviteCount,
    `Planned ${invitations.length} invitations, expected ${validated.expected.inviteCount}`,
  );
  assert(
    invitations.every((invitation) => invitation.hubIds.length > 0),
    "Every invitation must resolve to at least one hub",
  );
  const leagueWideCount = invitations.filter((invitation) =>
    invitation.hubIds.length === validated.expected.hubCount).length;
  const hubOnlyCount = invitations.filter((invitation) =>
    invitation.teamIds.length === 0 &&
    invitation.hubIds.length < validated.expected.hubCount).length;
  const teamScopedCount = invitations.filter((invitation) => invitation.teamIds.length > 0).length;
  assert(leagueWideCount === validated.expected.leagueWideCount, "League-wide invitation count changed");
  assert(hubOnlyCount === validated.expected.hubOnlyCount, "Hub-only invitation count changed");
  assert(teamScopedCount === validated.expected.teamScopedCount, "Team-scoped invitation count changed");
  return {...validated, invitations};
}

async function loadState(db, manifest, transaction = null) {
  const get = (target) => transaction ? transaction.get(target) : target.get();
  const orgRef = db.collection("organizations").doc(manifest.orgId);
  const leagueRef = orgRef.collection("leagues").doc(manifest.leagueId);
  const markerRef = orgRef.collection("auditLogs").doc(markerDocumentId(manifest.importId));
  const [orgDoc, leagueDoc, hubsSnap, usersSnap, invitationsSnap, markerDoc] = await Promise.all([
    get(orgRef),
    get(leagueRef),
    get(leagueRef.collection("hubs")),
    get(db.collection("users").where("orgId", "==", manifest.orgId)),
    get(orgRef.collection("invitations")),
    get(markerRef),
  ]);
  const teamSnaps = await Promise.all(hubsSnap.docs.map((hubDoc) =>
    get(hubDoc.ref.collection("teams"))));
  return {
    projectId: EXPECTED_PROJECT_ID,
    org: orgDoc.exists ? {id: orgDoc.id, ...orgDoc.data()} : null,
    league: leagueDoc.exists ? {id: leagueDoc.id, ...leagueDoc.data()} : null,
    hubs: hubsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    teams: teamSnaps.flatMap((snap) => snap.docs.map((doc) => ({id: doc.id, ...doc.data()}))),
    users: usersSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    invitations: invitationsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
    markerExists: markerDoc.exists,
    refs: {orgRef, markerRef},
  };
}

function parseArgs(argv) {
  const options = {apply: false};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--apply") {
      options.apply = true;
      continue;
    }
    const key = {
      "--manifest": "manifestPath",
      "--confirm-import-id": "confirmImportId",
      "--expected-create-count": "expectedCreateCount",
      "--confirm-manifest-sha256": "confirmManifestSha256",
    }[arg];
    assert(key, `Unknown argument: ${arg}`);
    const value = argv[index + 1];
    assert(value && !value.startsWith("--"), `${arg} requires a value`);
    options[key] = key === "expectedCreateCount" ? Number(value) : value;
    index += 1;
  }
  assert(options.manifestPath, "--manifest requires an absolute JSON manifest path");
  assert(path.isAbsolute(options.manifestPath), "--manifest must be an absolute path");
  return options;
}

function printPlan(plan, digest, apply) {
  const leagueWide = plan.invitations.filter((invitation) =>
    invitation.hubIds.length === plan.expected.hubCount).length;
  const hubOnly = plan.invitations.filter((invitation) =>
    invitation.teamIds.length === 0 &&
    invitation.hubIds.length < plan.expected.hubCount).length;
  const teamScoped = plan.invitations.filter((invitation) => invitation.teamIds.length > 0).length;
  console.log(JSON.stringify({
    mode: apply ? "APPLY" : "DRY RUN - NO WRITES OR EMAILS",
    projectId: plan.projectId,
    organization: `${plan.orgName} (${plan.orgId})`,
    league: `${plan.leagueName} (${plan.leagueId})`,
    importId: plan.importId,
    manifestSha256: digest,
    sourceSummary: plan.expected,
    invitationsToCreate: plan.invitations.length,
    leagueWide,
    hubOnly,
    teamScoped,
    writesOnApply: plan.invitations.length * 2 + 1,
  }, null, 2));
}

async function applyPlan(db, manifest, expectedPlan, digest) {
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + INVITATION_LIFETIME_MS);
  await db.runTransaction(async (transaction) => {
    const state = await loadState(db, manifest, transaction);
    const plan = buildImportPlan(manifest, state);
    assert(
      canonicalJson(plan.invitations) === canonicalJson(expectedPlan.invitations),
      "Production invitation plan changed after validation",
    );
    for (const invitation of plan.invitations) {
      const token = crypto.randomBytes(16).toString("hex");
      const invitationRef = state.refs.orgRef.collection("invitations").doc(invitation.id);
      transaction.create(invitationRef, {
        orgId: plan.orgId,
        email: invitation.email,
        displayName: invitation.displayName,
        title: invitation.title,
        role: invitation.role,
        leagueIds: invitation.leagueIds,
        hubIds: invitation.hubIds,
        teamIds: invitation.teamIds,
        invitedBy: SYSTEM_ACTOR_ID,
        invitedByName: plan.orgName,
        createdAt: now,
        expiresAt,
        status: "pending",
        token,
        emailDeliveryStatus: "pending",
        suppressAdminNotification: true,
        importId: plan.importId,
        sourceRows: invitation.sourceRows,
      });
      transaction.create(db.collection("invitationLookups").doc(token), {
        token,
        orgId: plan.orgId,
        invitationId: invitation.id,
        email: invitation.email,
        status: "pending",
        createdAt: now,
        expiresAt,
      });
    }
    transaction.create(state.refs.markerRef, {
      action: "bulkCreateInvitations",
      actorId: SYSTEM_ACTOR_ID,
      actorName: "Codex production import",
      actorEmail: null,
      actorRole: "system",
      createdAt: now,
      request: {
        importId: plan.importId,
        manifestSha256: digest,
        source: plan.source,
      },
      result: {
        invitationsCreated: plan.invitations.length,
        invitationLookupsCreated: plan.invitations.length,
      },
    });
  });
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const rawManifest = fs.readFileSync(options.manifestPath, "utf8");
  const manifest = validateManifest(JSON.parse(rawManifest));
  const digest = manifestSha256(manifest);
  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: EXPECTED_PROJECT_ID,
    });
  }
  const db = admin.firestore();
  const state = await loadState(db, manifest);
  const plan = buildImportPlan(manifest, state);
  printPlan(plan, digest, options.apply);
  if (!options.apply) return;

  assert(options.confirmImportId === manifest.importId, "--confirm-import-id does not match the manifest");
  assert(
    Number.isInteger(options.expectedCreateCount) &&
      options.expectedCreateCount === plan.invitations.length,
    "--expected-create-count does not match the live plan",
  );
  assert(
    options.confirmManifestSha256 === digest,
    "--confirm-manifest-sha256 does not match the validated manifest",
  );
  assert(plan.invitations.length > 0, "Refusing an empty invitation import");
  await applyPlan(db, manifest, plan, digest);
  console.log(`Applied ${plan.invitations.length} invitations atomically. Email delivery is now asynchronous.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  buildImportPlan,
  canonicalJson,
  invitationDocumentId,
  manifestSha256,
  markerDocumentId,
  normalizeEmail,
  parseArgs,
  validateManifest,
};
