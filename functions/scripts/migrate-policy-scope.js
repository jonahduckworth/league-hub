#!/usr/bin/env node

/*
 * Converts legacy league-only policies to organization-wide policies.
 *
 * The migration is read-only unless both --apply and the production project
 * are supplied explicitly. It also corrects the known policies that Richard
 * Nault physically uploaded while the admin browser was signed in as Jonah.
 */

const admin = require("firebase-admin");

const PROJECT_ID = "jdb-league-hub";
const APPLY = process.argv.includes("--apply");
const projectArg = process.argv.find((arg) => arg.startsWith("--project="));
const requestedProject = projectArg?.split("=")[1] ?? PROJECT_ID;
const knownCorrections = [
  {
    orgId: "JMl7VkKm9tAADBaxxdiI",
    policyId: "Z0ekfh7NMiyefYeMm66Z",
    expectedName: "JPHL Rivalry Games",
    expectedUploaderId: "aC9kl7nP1RRCTTaNbTqogO7k8Wv1",
    uploaderId: "q13wUYd13aZh5CEsRDxME8JtofX2",
    uploaderEmail: "rnault@jphlhockey.com",
    versions: [],
  },
  {
    orgId: "JMl7VkKm9tAADBaxxdiI",
    policyId: "cTnHEx0hfgAV6ciFY59e",
    expectedName: "JPHL Game Protocols (League Games)",
    expectedUploaderId: "aC9kl7nP1RRCTTaNbTqogO7k8Wv1",
    uploaderId: "q13wUYd13aZh5CEsRDxME8JtofX2",
    uploaderEmail: "rnault@jphlhockey.com",
    versions: [
      {
        version: 1,
        uploadedAt: "2026-08-17T20:20:36.627Z",
        fileSize: 177832,
      },
    ],
  },
];

function planUploaderCorrection(policyData, uploaderData, correction) {
  if (policyData.name !== correction.expectedName ||
      uploaderData.email !== correction.uploaderEmail ||
      uploaderData.orgId !== correction.orgId ||
      uploaderData.isActive !== true ||
      typeof uploaderData.displayName !== "string" ||
      uploaderData.displayName.trim().length === 0) {
    throw new Error(`Uploader correction preconditions do not match ${correction.policyId}.`);
  }

  const allowedUploaderIds = new Set([
    correction.expectedUploaderId,
    correction.uploaderId,
  ]);
  if (!allowedUploaderIds.has(policyData.uploadedBy)) {
    throw new Error(
      `Policy uploader changed unexpectedly for ${correction.policyId}; refusing to overwrite it.`,
    );
  }

  const versions = Array.isArray(policyData.versions) ? policyData.versions : [];
  const correctedVersions = versions.map((version) => ({...version}));
  let versionsChanged = 0;

  for (const expectedVersion of correction.versions) {
    const matchingIndexes = correctedVersions
      .map((version, index) => ({version, index}))
      .filter(({version}) =>
        version.version === expectedVersion.version &&
        version.uploadedAt === expectedVersion.uploadedAt &&
        version.fileSize === expectedVersion.fileSize,
      )
      .map(({index}) => index);
    if (matchingIndexes.length !== 1) {
      throw new Error(
        `Expected exactly one matching version for ${correction.policyId} v${expectedVersion.version}.`,
      );
    }

    const index = matchingIndexes[0];
    const version = correctedVersions[index];
    if (!allowedUploaderIds.has(version.uploadedBy)) {
      throw new Error(
        `Version uploader changed unexpectedly for ${correction.policyId} v${expectedVersion.version}.`,
      );
    }
    if (version.uploadedBy !== correction.uploaderId ||
        version.uploadedByName !== uploaderData.displayName) {
      correctedVersions[index] = {
        ...version,
        uploadedBy: correction.uploaderId,
        uploadedByName: uploaderData.displayName,
      };
      versionsChanged += 1;
    }
  }

  const rootChanged = policyData.uploadedBy !== correction.uploaderId ||
    policyData.uploadedByName !== uploaderData.displayName;
  const update = {};
  if (rootChanged) {
    update.uploadedBy = correction.uploaderId;
    update.uploadedByName = uploaderData.displayName;
  }
  if (versionsChanged > 0) update.versions = correctedVersions;

  return {
    from: policyData.uploadedByName,
    to: uploaderData.displayName,
    rootChanged,
    versionsChanged,
    update,
  };
}

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

async function main() {
  admin.initializeApp({projectId: PROJECT_ID});
  const db = admin.firestore();
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
          updateTime: policy.updateTime,
          orgId: organization.id,
          policyId: policy.id,
          name: data.name ?? policy.id,
        });
      }
    }
  }

  const uploaderCorrections = [];
  for (const correction of knownCorrections) {
    const correctionRef = db.doc(
      `organizations/${correction.orgId}/policies/${correction.policyId}`,
    );
    const [correctionSnap, uploaderSnap] = await Promise.all([
      correctionRef.get(),
      db.collection("users").doc(correction.uploaderId).get(),
    ]);
    if (!correctionSnap.exists || !uploaderSnap.exists) {
      throw new Error(`Uploader correction target is missing for ${correction.policyId}.`);
    }
    uploaderCorrections.push({
      ref: correctionRef,
      updateTime: correctionSnap.updateTime,
      correction,
      plan: planUploaderCorrection(
        correctionSnap.data() ?? {},
        uploaderSnap.data() ?? {},
        correction,
      ),
    });
  }

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    mode: APPLY ? "apply" : "dry-run",
    leaguePoliciesToOrganizationWide: scopeUpdates.length,
    policies: scopeUpdates.map(({orgId, policyId, name}) => ({orgId, policyId, name})),
    uploaderCorrections: uploaderCorrections.map(({correction, plan}) => ({
      orgId: correction.orgId,
      policyId: correction.policyId,
      name: correction.expectedName,
      from: plan.from,
      to: plan.to,
      rootCorrectionRequired: plan.rootChanged,
      versionsToCorrect: plan.versionsChanged,
    })),
  }, null, 2));

  if (!APPLY) return;

  const batch = db.batch();
  for (const update of scopeUpdates) {
    batch.update(
      update.ref,
      {leagueId: null},
      {lastUpdateTime: update.updateTime},
    );
  }
  for (const uploaderCorrection of uploaderCorrections) {
    if (Object.keys(uploaderCorrection.plan.update).length > 0) {
      batch.update(
        uploaderCorrection.ref,
        uploaderCorrection.plan.update,
        {lastUpdateTime: uploaderCorrection.updateTime},
      );
    }
  }
  if (scopeUpdates.length > 0 ||
      uploaderCorrections.some(({plan}) => Object.keys(plan.update).length > 0)) {
    await batch.commit();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {planUploaderCorrection};
