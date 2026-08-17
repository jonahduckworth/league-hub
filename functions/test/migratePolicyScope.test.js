const assert = require("node:assert/strict");
const test = require("node:test");

const {
  planUploaderCorrection,
} = require("../scripts/migrate-policy-scope");

const correction = {
  orgId: "org-1",
  policyId: "policy-1",
  expectedName: "Game Protocols",
  expectedUploaderId: "jonah",
  uploaderId: "richard",
  uploaderEmail: "richard@example.com",
  versions: [
    {version: 1, uploadedAt: "2026-08-17T20:20:36.627Z", fileSize: 177832},
  ],
};

const uploader = {
  email: "richard@example.com",
  orgId: "org-1",
  isActive: true,
  displayName: "Richard Nault",
};

function policy(overrides = {}) {
  return {
    name: "Game Protocols",
    uploadedBy: "jonah",
    uploadedByName: "Jonah Duckworth",
    versions: [
      {
        version: 1,
        uploadedAt: "2026-08-17T20:20:36.627Z",
        fileSize: 177832,
        uploadedBy: "jonah",
        uploadedByName: "Jonah Duckworth",
        url: "https://example.com/v1.pdf",
      },
      {
        version: 2,
        uploadedAt: "2026-08-18T20:20:36.627Z",
        fileSize: 200000,
        uploadedBy: "someone-else",
        uploadedByName: "Someone Else",
        url: "https://example.com/v2.pdf",
      },
    ],
    ...overrides,
  };
}

test("corrects the guarded policy root and exact known version only", () => {
  const result = planUploaderCorrection(policy(), uploader, correction);

  assert.equal(result.rootChanged, true);
  assert.equal(result.versionsChanged, 1);
  assert.equal(result.update.uploadedBy, "richard");
  assert.equal(result.update.uploadedByName, "Richard Nault");
  assert.deepEqual(result.update.versions[0], {
    version: 1,
    uploadedAt: "2026-08-17T20:20:36.627Z",
    fileSize: 177832,
    uploadedBy: "richard",
    uploadedByName: "Richard Nault",
    url: "https://example.com/v1.pdf",
  });
  assert.equal(result.update.versions[1].uploadedBy, "someone-else");
});

test("is idempotent after the guarded correction has been applied", () => {
  const result = planUploaderCorrection(policy({
    uploadedBy: "richard",
    uploadedByName: "Richard Nault",
    versions: [{
      version: 1,
      uploadedAt: "2026-08-17T20:20:36.627Z",
      fileSize: 177832,
      uploadedBy: "richard",
      uploadedByName: "Richard Nault",
    }],
  }), uploader, correction);

  assert.equal(result.rootChanged, false);
  assert.equal(result.versionsChanged, 0);
  assert.deepEqual(result.update, {});
});

test("refuses unexpected policy or version attribution", () => {
  assert.throws(
    () => planUploaderCorrection(policy({name: "Other Policy"}), uploader, correction),
    /preconditions do not match/,
  );
  assert.throws(
    () => planUploaderCorrection(policy({uploadedBy: "unexpected"}), uploader, correction),
    /Policy uploader changed unexpectedly/,
  );
  assert.throws(
    () => planUploaderCorrection(policy({
      versions: [{
        version: 1,
        uploadedAt: "2026-08-17T20:20:36.627Z",
        fileSize: 177832,
        uploadedBy: "unexpected",
      }],
    }), uploader, correction),
    /Version uploader changed unexpectedly/,
  );
});

test("refuses a missing or ambiguous targeted version", () => {
  assert.throws(
    () => planUploaderCorrection(policy({versions: []}), uploader, correction),
    /Expected exactly one matching version/,
  );
  const duplicate = policy().versions[0];
  assert.throws(
    () => planUploaderCorrection(policy({versions: [duplicate, duplicate]}), uploader, correction),
    /Expected exactly one matching version/,
  );
});
