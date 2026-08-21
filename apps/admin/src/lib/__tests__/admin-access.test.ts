import { describe, expect, it } from "vitest";
import { assignableRoles, canAccessAdmin, canManageUser, canManageUserAssignments, roleDetails, roleLabel } from "../admin-access";
import type { AppUser } from "../types";

const baseUser: AppUser = {
  id: "user",
  email: "user@example.com",
  displayName: "User",
  role: "staff",
  orgId: "org-1",
  hubIds: [],
  leagueIds: [],
  teamIds: [],
  isActive: true
};

describe("admin access helpers", () => {
  it("allows only active platform owners and super admins into the admin app", () => {
    expect(canAccessAdmin({ ...baseUser, role: "platformOwner" })).toBe(true);
    expect(canAccessAdmin({ ...baseUser, role: "superAdmin" })).toBe(true);
    expect(canAccessAdmin({ ...baseUser, role: "managerAdmin" })).toBe(false);
    expect(canAccessAdmin({ ...baseUser, role: "staff" })).toBe(false);
    expect(canAccessAdmin({ ...baseUser, role: "superAdmin", isActive: false })).toBe(false);
  });

  it("matches the mobile assignable role rules", () => {
    expect(assignableRoles({ ...baseUser, role: "platformOwner" })).toEqual(["superAdmin", "managerAdmin", "staff"]);
    expect(assignableRoles({ ...baseUser, role: "superAdmin" })).toEqual(["managerAdmin", "staff"]);
    expect(assignableRoles({ ...baseUser, role: "managerAdmin" })).toEqual([]);
  });

  it("prevents self edits, peer admin edits, and cross-org super admin edits", () => {
    const actor = { ...baseUser, id: "admin", role: "superAdmin" as const };
    expect(canManageUser(actor, { ...baseUser, id: "staff", role: "staff" })).toBe(true);
    expect(canManageUser(actor, { ...baseUser, id: "admin", role: "superAdmin" })).toBe(false);
    expect(canManageUser(actor, { ...baseUser, id: "peer", role: "superAdmin" })).toBe(false);
    expect(canManageUser(actor, { ...baseUser, id: "staff-2", role: "staff", orgId: "org-2" })).toBe(false);
  });

  it("allows same-org peer admins to edit assignments without full control", () => {
    const actor = { ...baseUser, id: "admin", role: "superAdmin" as const };
    const peer = { ...baseUser, id: "peer", role: "superAdmin" as const };

    expect(canManageUser(actor, peer)).toBe(false);
    expect(canManageUserAssignments(actor, peer)).toBe(true);
    expect(canManageUserAssignments(actor, { ...peer, orgId: "org-2" })).toBe(false);
    expect(canManageUserAssignments(actor, { ...peer, role: "platformOwner" })).toBe(false);
    expect(canManageUserAssignments(actor, actor)).toBe(false);
  });

  it("renders human role labels", () => {
    expect(roleLabel("platformOwner")).toBe("Platform Owner");
    expect(roleLabel("managerAdmin")).toBe("Manager");
  });

  it("explains access for every role", () => {
    expect(roleDetails("platformOwner").headline).toBe("Cross-organization control");
    expect(roleDetails("superAdmin").headline).toBe("Full organization access");
    expect(roleDetails("managerAdmin").headline).toBe("Assigned hubs and teams");
    expect(roleDetails("staff").headline).toBe("Standard team access");
  });
});
