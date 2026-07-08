import { describe, expect, it } from "vitest";
import { formatAdminActionError } from "../action-errors";

describe("formatAdminActionError", () => {
  it("explains internal callable failures as a backend availability issue", () => {
    expect(formatAdminActionError({ code: "functions/internal", message: "internal" })).toContain("admin Cloud Functions");
  });

  it("keeps permission failures user-facing", () => {
    expect(formatAdminActionError({ code: "functions/permission-denied", message: "Forbidden" })).toBe(
      "You do not have permission to complete that admin action."
    );
  });
});
