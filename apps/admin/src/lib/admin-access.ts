import type { AppUser, UserRole } from "./types";

const roleOrder: UserRole[] = ["platformOwner", "superAdmin", "managerAdmin", "staff"];

export function isAdminRole(role: unknown): role is "platformOwner" | "superAdmin" {
  return role === "platformOwner" || role === "superAdmin";
}

export function canAccessAdmin(user?: Pick<AppUser, "role" | "isActive"> | null): boolean {
  return Boolean(user?.isActive && isAdminRole(user.role));
}

export function roleLabel(role: UserRole | string): string {
  switch (role) {
    case "platformOwner":
      return "Platform Owner";
    case "superAdmin":
      return "Admin";
    case "managerAdmin":
      return "Manager";
    case "staff":
      return "Staff";
    default:
      return role;
  }
}

export function assignableRoles(actor?: Pick<AppUser, "role"> | null): UserRole[] {
  if (actor?.role === "platformOwner") return ["superAdmin", "managerAdmin", "staff"];
  if (actor?.role === "superAdmin") return ["managerAdmin", "staff"];
  return [];
}

export function outranks(actorRole: UserRole, targetRole: UserRole): boolean {
  return roleOrder.indexOf(actorRole) < roleOrder.indexOf(targetRole);
}

export function canManageUser(actor: AppUser, target: AppUser): boolean {
  if (!canAccessAdmin(actor)) return false;
  if (actor.id === target.id) return false;
  if (target.role === "platformOwner") return false;
  if (!outranks(actor.role, target.role)) return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId != null && actor.orgId === target.orgId;
}
