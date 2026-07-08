import { describe, expect, it } from "vitest";
import {
  POLICY_FILE_MAX_BYTES,
  isPolicyFileAllowed,
  policyStoragePath,
  sanitizeStorageFileName
} from "../policy-upload";

describe("policy upload helpers", () => {
  it("sanitizes storage file names", () => {
    expect(sanitizeStorageFileName("  Safety Policy (Final).pdf ")).toBe("Safety-Policy-Final.pdf");
  });

  it("builds policy storage paths under the allowed Storage rules location", () => {
    expect(policyStoragePath("org-1", "policy-1", "Safety Policy.pdf", 123)).toBe(
      "organizations/org-1/policies/policy-1/123-Safety-Policy.pdf"
    );
  });

  it("allows files at or under the policy upload limit", () => {
    expect(isPolicyFileAllowed({ size: POLICY_FILE_MAX_BYTES })).toBe(true);
    expect(isPolicyFileAllowed({ size: POLICY_FILE_MAX_BYTES + 1 })).toBe(false);
  });
});
