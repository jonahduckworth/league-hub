export type UserRole = "platformOwner" | "superAdmin" | "managerAdmin" | "staff";

export type ActorLike = {
  id: string;
  orgId?: string | null;
  role?: string | null;
  isActive?: boolean | null;
};

export type TargetLike = {
  id: string;
  orgId?: string | null;
  role?: string | null;
};

const roleOrder: UserRole[] = [
  "platformOwner",
  "superAdmin",
  "managerAdmin",
  "staff",
];

export function isUserRole(role: unknown): role is UserRole {
  return typeof role === "string" && roleOrder.includes(role as UserRole);
}

export function isAdminRole(role: unknown): role is "platformOwner" | "superAdmin" {
  return role === "platformOwner" || role === "superAdmin";
}

export function canAccessOrg(actor: ActorLike, orgId: string): boolean {
  if (!actor.isActive || !isAdminRole(actor.role)) return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId === orgId;
}

export function outranks(actorRole: unknown, targetRole: unknown): boolean {
  if (!isUserRole(actorRole) || !isUserRole(targetRole)) return false;
  return roleOrder.indexOf(actorRole) < roleOrder.indexOf(targetRole);
}

export function assignableRoles(actorRole: unknown): UserRole[] {
  if (actorRole === "platformOwner") {
    return ["superAdmin", "managerAdmin", "staff"];
  }
  if (actorRole === "superAdmin") {
    return ["managerAdmin", "staff"];
  }
  return [];
}

export function canManageTarget(actor: ActorLike, target: TargetLike): boolean {
  if (!actor.isActive || !isAdminRole(actor.role)) return false;
  if (actor.id === target.id) return false;
  if (target.role === "platformOwner") return false;
  if (!outranks(actor.role, target.role)) return false;
  if (actor.role === "platformOwner") return true;
  return actor.orgId != null && actor.orgId === target.orgId;
}

export function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((item): item is string => {
    return typeof item === "string" && item.trim().length > 0;
  }).map((item) => item.trim()))];
}

