import type { AdminData, Invitation } from "./types";
import { toDate } from "./format";

function normalizeEmail(email?: string | null): string {
  return email?.trim().toLowerCase() ?? "";
}

function invitationTime(value: unknown): number | null {
  return toDate(value)?.getTime() ?? null;
}

export function activePendingInvitations(
  data: Pick<AdminData, "users" | "invitations">,
  now = Date.now()
): Invitation[] {
  const activeEmails = new Set(
    data.users
      .filter((user) => user.isActive)
      .map((user) => normalizeEmail(user.email))
      .filter(Boolean)
  );

  return data.invitations.filter((invite) => {
    if (invite.status !== "pending") return false;
    const expiresAt = toDate(invite.expiresAt);
    if (!expiresAt || expiresAt.getTime() <= now) return false;
    const inviteEmail = normalizeEmail(invite.email);
    return inviteEmail.length === 0 || !activeEmails.has(inviteEmail);
  });
}

export function resendableExpiredInvitations(
  data: Pick<AdminData, "users" | "invitations">,
  now = Date.now()
): Invitation[] {
  const activeEmails = new Set(
    data.users
      .filter((user) => user.isActive)
      .map((user) => normalizeEmail(user.email))
      .filter(Boolean)
  );
  const activePendingEmails = new Set(
    activePendingInvitations(data, now)
      .map((invite) => normalizeEmail(invite.email))
      .filter(Boolean)
  );
  const latestByEmail = new Map<string, Invitation>();

  for (const invite of data.invitations) {
    const expiresAt = invitationTime(invite.expiresAt);
    const isExpired = invite.status === "expired" ||
      (invite.status === "pending" && expiresAt !== null && expiresAt <= now);
    const email = normalizeEmail(invite.email);
    if (!isExpired || !email || activeEmails.has(email) || activePendingEmails.has(email)) continue;

    const current = latestByEmail.get(email);
    const inviteTime = invitationTime(invite.createdAt) ?? expiresAt ?? 0;
    const currentTime = current
      ? invitationTime(current.createdAt) ?? invitationTime(current.expiresAt) ?? 0
      : -1;
    if (!current || inviteTime > currentTime) latestByEmail.set(email, invite);
  }

  return [...latestByEmail.values()].sort((first, second) => {
    const firstTime = invitationTime(first.createdAt) ?? invitationTime(first.expiresAt) ?? 0;
    const secondTime = invitationTime(second.createdAt) ?? invitationTime(second.expiresAt) ?? 0;
    return secondTime - firstTime || first.email.localeCompare(second.email);
  });
}
