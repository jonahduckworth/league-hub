import type { AppUser, UserRole } from "./types";

const roleOrder: UserRole[] = ["platformOwner", "superAdmin", "managerAdmin", "staff"];

export type RoleDetails = {
  headline: string;
  description: string;
  assignmentGuidance: string;
};

const roleDetailsByRole: Record<UserRole, RoleDetails> = {
  platformOwner: {
    headline: "Cross-organization control",
    description: "Controls organizations and league creation across the platform.",
    assignmentGuidance: "Platform Owners work across every organization."
  },
  superAdmin: {
    headline: "Full organization access",
    description: "Manage existing leagues, hubs, teams, people, announcements, policies, and chat rooms.",
    assignmentGuidance: "Admins automatically have access to the full organization. Assignments are optional and can be kept for a future role change."
  },
  managerAdmin: {
    headline: "Assigned hubs and teams",
    description: "Manage assigned hubs, teams, staff, announcements, policies, and chat rooms.",
    assignmentGuidance: "Choose the hubs this manager is responsible for, then select teams within those hubs."
  },
  staff: {
    headline: "Standard team access",
    description: "View shared content, rosters, and policies, participate in chats, and update their profile.",
    assignmentGuidance: "Choose the hubs and teams this staff member should be able to access."
  }
};

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

export function roleDetails(role: UserRole): RoleDetails {
  return roleDetailsByRole[role];
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

export function canManageUserAssignments(actor: AppUser, target: AppUser): boolean {
  if (!canAccessAdmin(actor)) return false;
  if (actor.id === target.id || target.role === "platformOwner") return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId != null && actor.orgId === target.orgId;
}
