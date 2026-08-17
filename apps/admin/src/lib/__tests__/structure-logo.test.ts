import { describe, expect, it } from "vitest";
import {
  maxStructureLogoBytes,
  structureLogoStoragePath,
  validateStructureLogoFile
} from "../structure-logo";

describe("structure logo uploads", () => {
  it("accepts supported image formats within the size limit", () => {
    expect(validateStructureLogoFile({ name: "team.png", size: 1024, type: "image/png" })).toBeNull();
    expect(validateStructureLogoFile({ name: "team.jpg", size: maxStructureLogoBytes, type: "image/jpeg" })).toBeNull();
    expect(validateStructureLogoFile({ name: "team.webp", size: 2048, type: "image/webp" })).toBeNull();
  });

  it("rejects unsupported, empty, and oversized files", () => {
    expect(validateStructureLogoFile({ name: "team.svg", size: 1024, type: "image/svg+xml" })).toMatch(/PNG, JPG, or WebP/);
    expect(validateStructureLogoFile({ name: "team.png", size: 0, type: "image/png" })).toMatch(/empty/);
    expect(validateStructureLogoFile({ name: "team.png", size: maxStructureLogoBytes + 1, type: "image/png" })).toMatch(/10 MB/);
  });

  it("builds a rules-compatible path with a sanitized file name", () => {
    expect(structureLogoStoragePath({
      orgId: "org-1",
      entityType: "team",
      entityId: "team-1",
      userId: "admin-1",
      fileName: "Wolves HC (17U).png",
      timestamp: 123
    })).toBe("orgs/org-1/logos/team/team-1/admin-1/123_Wolves_HC__17U_.png");
  });
});
