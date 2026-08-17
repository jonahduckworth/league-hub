import { describe, expect, it, vi } from "vitest";
import {
  POLICY_FILE_MAX_BYTES,
  isPolicyFileAllowed,
  POLICY_CATEGORIES,
  policyStoragePath,
  sanitizeStorageFileName,
  runReservedPolicyUpload
} from "../policy-upload";

describe("policy upload helpers", () => {
  it("uses the mobile policy category taxonomy", () => {
    expect(POLICY_CATEGORIES).toEqual(["Policy", "Protocol", "Code of Conduct", "Other"]);
  });
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

  it("reserves metadata before Storage upload and finalizes afterward", async () => {
    const order: string[] = [];
    const fileUrl = await runReservedPolicyUpload({
      reserve: async () => { order.push("reserve"); },
      upload: async () => { order.push("upload"); return "https://example.com/policy.pdf"; },
      finalize: async () => { order.push("finalize"); },
      cleanupFile: vi.fn(),
      cleanupPolicy: vi.fn()
    });

    expect(fileUrl).toBe("https://example.com/policy.pdf");
    expect(order).toEqual(["reserve", "upload", "finalize"]);
  });

  it("cleans up both file and reservation when finalization fails", async () => {
    const cleanupFile = vi.fn(async () => undefined);
    const cleanupPolicy = vi.fn(async () => undefined);

    await expect(runReservedPolicyUpload({
      reserve: async () => undefined,
      upload: async () => "https://example.com/policy.pdf",
      finalize: async () => { throw new Error("finalization failed"); },
      cleanupFile,
      cleanupPolicy
    })).rejects.toThrow("finalization failed");

    expect(cleanupFile).toHaveBeenCalledOnce();
    expect(cleanupPolicy).toHaveBeenCalledOnce();
  });
});
