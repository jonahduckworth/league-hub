#!/usr/bin/env node

/*
 * Removes the retired physical-address field from top-level user profiles.
 * Safe by default: omit --apply for a read-only report.
 */

const PROJECT_ID = "jdb-league-hub";

function parseArgs(args) {
  let apply = false;
  let projectId = null;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--apply") {
      apply = true;
      continue;
    }
    if (arg === "--project") {
      projectId = args[index + 1] ?? null;
      index += 1;
      continue;
    }
    if (arg.startsWith("--project=")) {
      projectId = arg.slice("--project=".length);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (projectId !== PROJECT_ID) {
    throw new Error(`Pass --project ${PROJECT_ID} to confirm the target project.`);
  }

  return {apply, projectId};
}

function profilesWithAddress(snapshot) {
  return snapshot.docs.filter((document) =>
    Object.prototype.hasOwnProperty.call(document.data(), "address"));
}

async function runMigration({admin, apply, projectId, log = console.log}) {
  if (admin.apps.length === 0) admin.initializeApp({projectId});
  const db = admin.firestore();
  const snapshot = await db.collection("users").get();
  const matchingProfiles = profilesWithAddress(snapshot);

  log(JSON.stringify({
    projectId,
    mode: apply ? "apply" : "dry-run",
    scannedProfiles: snapshot.size,
    profilesWithAddress: matchingProfiles.length,
  }, null, 2));

  if (!apply || matchingProfiles.length === 0) return;

  for (let offset = 0; offset < matchingProfiles.length; offset += 200) {
    const batch = db.batch();
    for (const profile of matchingProfiles.slice(offset, offset + 200)) {
      batch.update(profile.ref, {
        address: admin.firestore.FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  const verification = await db.collection("users").get();
  const remaining = profilesWithAddress(verification).length;
  log(JSON.stringify({projectId, verification: {remaining}}, null, 2));
  if (remaining !== 0) {
    throw new Error(`Verification failed: ${remaining} profiles still contain address.`);
  }
}

if (require.main === module) {
  const admin = require("firebase-admin");
  const options = parseArgs(process.argv.slice(2));
  runMigration({admin, ...options}).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {parseArgs, profilesWithAddress, runMigration};
