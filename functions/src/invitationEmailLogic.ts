import {createHash} from "crypto";

export type InvitationEmailInput = {
  recipientName?: string | null;
  organizationName: string;
  invitedByName: string;
  role: string;
  token: string;
};

export type InvitationEmail = {
  subject: string;
  text: string;
  html: string;
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function roleLabel(role: string): string {
  switch (role) {
  case "superAdmin":
    return "Admin";
  case "managerAdmin":
    return "Manager";
  case "staff":
    return "Staff";
  default:
    return "Member";
  }
}

export function normalizeInvitationRecipient(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (email.length === 0 || email.length > 254) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

export function normalizeInvitationToken(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const token = value.trim().toLowerCase();
  return /^[a-f0-9]{32}$/.test(token) ? token : null;
}

export function invitationIdempotencyKey(
  orgId: string,
  invitationId: string,
): string {
  const digest = createHash("sha256")
    .update(`${orgId}:${invitationId}`)
    .digest("hex")
    .slice(0, 40);
  return `league-hub-invite-${digest}`;
}

export function buildInvitationEmail(input: InvitationEmailInput): InvitationEmail {
  const organizationName = input.organizationName.trim() || "your organization";
  const invitedByName = input.invitedByName.trim() || "A League Hub administrator";
  const recipientName = input.recipientName?.trim();
  const greeting = recipientName ? `Hi ${recipientName},` : "Hi,";
  const assignedRole = roleLabel(input.role);
  const subject = `You're invited to join ${organizationName} on League Hub`;
  const text = [
    greeting,
    "",
    `${invitedByName} invited you to join ${organizationName} as ${assignedRole}.`,
    "",
    `Your invitation code is: ${input.token}`,
    "",
    "To join:",
    "1. Open the League Hub app.",
    "2. On the sign-in screen, choose Accept Invitation.",
    "3. Enter the invitation code above and create your account.",
    "",
    "This invitation expires after 7 days. If you were not expecting it, you can ignore this email.",
    "",
    "League Hub",
  ].join("\n");

  const safeGreeting = escapeHtml(greeting);
  const safeInviter = escapeHtml(invitedByName);
  const safeOrganization = escapeHtml(organizationName);
  const safeRole = escapeHtml(assignedRole);
  const safeToken = escapeHtml(input.token);
  const html = `<!doctype html><html><body style="margin:0;background:#f2f6fa;font-family:Arial,sans-serif;color:#061a33"><main style="max-width:620px;margin:32px auto;background:#fff;border:1px solid #d9e5f1;border-radius:20px;overflow:hidden"><div style="background:#06182c;padding:24px 28px;color:#fff"><p style="margin:0;font-size:13px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#64e0dc">League Hub</p><h1 style="margin:10px 0 0;font-size:25px;line-height:1.25">You're invited</h1></div><div style="padding:28px"><p style="margin:0 0 16px">${safeGreeting}</p><p style="margin:0 0 20px;line-height:1.6"><strong>${safeInviter}</strong> invited you to join <strong>${safeOrganization}</strong> as <strong>${safeRole}</strong>.</p><div style="margin:22px 0;padding:18px;border-radius:14px;background:#eafafa;border:1px solid #bcebea"><p style="margin:0 0 8px;font-size:12px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:#087e91">Invitation code</p><p style="margin:0;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:22px;font-weight:800;letter-spacing:.04em;word-break:break-all">${safeToken}</p></div><h2 style="margin:24px 0 10px;font-size:18px">How to join</h2><ol style="margin:0;padding-left:22px;line-height:1.8"><li>Open the League Hub app.</li><li>On the sign-in screen, choose <strong>Accept Invitation</strong>.</li><li>Enter the invitation code above and create your account.</li></ol><p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#59708e">This invitation expires after 7 days. If you were not expecting it, you can ignore this email.</p></div></main></body></html>`;

  return {subject, text, html};
}

export function requireSuccessfulInvitationDelivery(
  status: number,
  responseBody: string,
): void {
  if (status >= 200 && status < 300) return;
  throw new Error(
    `Invitation email delivery failed (${status}): ${responseBody.slice(0, 200)}`,
  );
}
