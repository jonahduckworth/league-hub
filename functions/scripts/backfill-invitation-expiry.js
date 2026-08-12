#!/usr/bin/env node

/*
 * Adds authoritative seven-day expiry timestamps to legacy pending invites.
 * Safe by default: omit --apply for a read-only production report.
 */

const admin = require("firebase-admin");

const PROJECT_ID = "jdb-league-hub";
const APPLY = process.argv.includes("--apply");
const unknownArgs = process.argv.slice(2).filter((arg) => arg !== "--apply");
const invitationLifetimeMs = 7 * 24 * 60 * 60 * 1000;

if (unknownArgs.length > 0) {
  throw new Error(`Unknown arguments: ${unknownArgs.join(", ")}`);
}

admin.initializeApp({projectId: PROJECT_ID});
const db = admin.firestore();

function asDate(value) {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

async function main() {
  const organizations = await db.collection("organizations").get();
  const now = Date.now();
  const planned = [];

  for (const organization of organizations.docs) {
    const invitations = await organization.ref.collection("invitations")
      .where("status", "==", "pending")
      .get();
    for (const invitation of invitations.docs) {
      const data = invitation.data();
      if (data.expiresAt instanceof admin.firestore.Timestamp) continue;
      const createdAt = asDate(data.createdAt);
      const expiresAt = createdAt == null ? null : new Date(
        createdAt.getTime() + invitationLifetimeMs,
      );
      planned.push({
        invitation,
        token: typeof data.token === "string" ? data.token : null,
        expiresAt,
        expire: expiresAt == null || expiresAt.getTime() <= now,
      });
    }
  }

  const expiring = planned.filter((item) => item.expire).length;
  const backfilling = planned.length - expiring;
  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    mode: APPLY ? "apply" : "dry-run",
    pendingWithoutExpiry: planned.length,
    backfilling,
    expiring,
  }, null, 2));

  if (!APPLY || planned.length === 0) return;

  for (let offset = 0; offset < planned.length; offset += 200) {
    const batch = db.batch();
    for (const item of planned.slice(offset, offset + 200)) {
      const expiresAt = item.expiresAt == null
        ? admin.firestore.Timestamp.fromMillis(0)
        : admin.firestore.Timestamp.fromDate(item.expiresAt);
      batch.set(item.invitation.ref, item.expire ? {
        status: "expired",
        expiresAt,
      } : {expiresAt}, {merge: true});
      if (item.token) {
        batch.set(db.collection("invitationLookups").doc(item.token),
          item.expire ? {status: "expired", expiresAt} : {expiresAt},
          {merge: true});
      }
    }
    await batch.commit();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
