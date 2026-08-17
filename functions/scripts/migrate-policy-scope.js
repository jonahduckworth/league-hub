#!/usr/bin/env node

/*
 * Converts legacy league-only policies to organization-wide policies.
 *
 * The migration is read-only unless both --apply and the production project
 * are supplied explicitly. It also corrects the one known policy that Richard
 * Nault physically uploaded while the admin browser was signed in as Jonah.
 */

const admin = require("firebase-admin");

const PROJECT_ID = "jdb-league-hub";
const APPLY = process.argv.includes("--apply");
const projectArg = process.argv.find((arg) => arg.startsWith("--project="));
const requestedProject = projectArg?.split("=")[1] ?? PROJECT_ID;
const knownCorrection = {
  orgId: "JMl7VkKm9tAADBaxxdiI",
  policyId: "Z0ekfh7NMiyefYeMm66Z",
  expectedName: "JPHL Rivalry Games",
  expectedUploaderId: "aC9kl7nP1RRCTTaNbTqogO7k8Wv1",
  uploaderId: "q13wUYd13aZh5CEsRDxME8JtofX2",
  uploaderEmail: "rnault@jphlhockey.com",
};

const knownArgs = new Set(["--apply", `--project=${requestedProject}`]);
const unknownArgs = process.argv.slice(2).filter((arg) => !knownArgs.has(arg));
if (unknownArgs.length > 0) {
  throw new Error(`Unknown arguments: ${unknownArgs.join(", ")}`);
}
if (requestedProject !== PROJECT_ID) {
  throw new Error(`Refusing unexpected project ${requestedProject}.`);
}
if (APPLY && projectArg == null) {
  throw new Error(`Applying requires --project=${PROJECT_ID}.`);
}
if (APPLY && process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("Refusing production migration while FIRESTORE_EMULATOR_HOST is set.");
}

admin.initializeApp({projectId: PROJECT_ID});
const db = admin.firestore();

async function main() {
  const organizations = await db.collection("organizations").get();
  const scopeUpdates = [];

  for (const organization of organizations.docs) {
    const policies = await organization.ref.collection("policies").get();
    for (const policy of policies.docs) {
      const data = policy.data();
      if (typeof data.leagueId === "string" &&
          data.leagueId.length > 0 &&
          data.hubId == null &&
          data.teamId == null) {
        scopeUpdates.push({
          ref: policy.ref,
          orgId: organization.id,
          policyId: policy.id,
          name: data.name ?? policy.id,
        });
      }
    }
  }

  const correctionRef = db.doc(
    `organizations/${knownCorrection.orgId}/policies/${knownCorrection.policyId}`,
  );
  const [correctionSnap, uploaderSnap] = await Promise.all([
    correctionRef.get(),
    db.collection("users").doc(knownCorrection.uploaderId).get(),
  ]);
  if (!correctionSnap.exists || !uploaderSnap.exists) {
    throw new Error("Known uploader correction target is missing.");
  }
  const correctionData = correctionSnap.data() ?? {};
  const uploaderData = uploaderSnap.data() ?? {};
  if (correctionData.name !== knownCorrection.expectedName ||
      uploaderData.email !== knownCorrection.uploaderEmail ||
      uploaderData.orgId !== knownCorrection.orgId ||
      uploaderData.isActive !== true) {
    throw new Error("Known uploader correction preconditions do not match production.");
  }

  const alreadyCorrected = correctionData.uploadedBy === knownCorrection.uploaderId &&
    correctionData.uploadedByName === uploaderData.displayName;
  const correctionMatchesExpected = alreadyCorrected ||
    correctionData.uploadedBy === knownCorrection.expectedUploaderId;
  if (!correctionMatchesExpected) {
    throw new Error("Known policy uploader changed unexpectedly; refusing to overwrite it.");
  }

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    mode: APPLY ? "apply" : "dry-run",
    leaguePoliciesToOrganizationWide: scopeUpdates.length,
    policies: scopeUpdates.map(({orgId, policyId, name}) => ({orgId, policyId, name})),
    uploaderCorrection: {
      orgId: knownCorrection.orgId,
      policyId: knownCorrection.policyId,
      from: correctionData.uploadedByName,
      to: uploaderData.displayName,
      required: !alreadyCorrected,
    },
  }, null, 2));

  if (!APPLY) return;

  const batch = db.batch();
  for (const update of scopeUpdates) {
    batch.update(update.ref, {leagueId: null});
  }
  if (!alreadyCorrected) {
    batch.update(correctionRef, {
      uploadedBy: knownCorrection.uploaderId,
      uploadedByName: uploaderData.displayName,
    });
  }
  if (scopeUpdates.length > 0 || !alreadyCorrected) {
    await batch.commit();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
