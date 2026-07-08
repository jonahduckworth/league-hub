import type { AdminData, Invitation } from "./types";

function normalizeEmail(email?: string | null): string {
  return email?.trim().toLowerCase() ?? "";
}

export function activePendingInvitations(
  data: Pick<AdminData, "users" | "invitations">
): Invitation[] {
  const activeEmails = new Set(
    data.users
      .filter((user) => user.isActive)
      .map((user) => normalizeEmail(user.email))
      .filter(Boolean)
  );

  return data.invitations.filter((invite) => {
    if (invite.status !== "pending") return false;
    const inviteEmail = normalizeEmail(invite.email);
    return inviteEmail.length === 0 || !activeEmails.has(inviteEmail);
  });
}
