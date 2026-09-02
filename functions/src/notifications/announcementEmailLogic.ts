import {createHash} from "crypto";

export type AnnouncementEmailInput = {
  recipientName?: string | null;
  organizationName: string;
  title: string;
  body: string;
  authorName: string;
  scope: string;
  announcementId: string;
  isPinned: boolean;
};

export type AnnouncementEmail = {
  subject: string;
  text: string;
  html: string;
};

export type AnnouncementDeliveryFailure = {
  retryable: boolean;
  deliveryStatus: "retrying" | "failed";
  code: string;
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function cleanText(value: string, fallback: string, maximum: number): string {
  const normalized = value.trim();
  return (normalized || fallback).slice(0, maximum);
}

function scopeLabel(value: string): string {
  switch (value) {
  case "team":
    return "Team";
  case "hub":
    return "Hub";
  default:
    return "League";
  }
}

export function normalizeAnnouncementRecipient(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (email.length === 0 || email.length > 254) return null;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

export function announcementBatchIdempotencyKey(
  orgId: string,
  announcementId: string,
  recipientIds: string[],
): string {
  const digest = createHash("sha256")
    .update(`${orgId}:${announcementId}:${[...recipientIds].sort().join(":")}`)
    .digest("hex")
    .slice(0, 48);
  return `league-hub-announcement-${digest}`;
}

export function buildAnnouncementEmail(
  input: AnnouncementEmailInput,
): AnnouncementEmail {
  const organizationName = cleanText(
    input.organizationName,
    "League Hub",
    160,
  );
  const title = cleanText(input.title, "New announcement", 200);
  const body = cleanText(input.body, "Open League Hub to read this announcement.", 12000);
  const authorName = cleanText(input.authorName, "A League Hub administrator", 160);
  const greetingName = input.recipientName?.trim().slice(0, 160);
  const greeting = greetingName ? `Hi ${greetingName},` : "Hi,";
  const audience = scopeLabel(input.scope);
  const announcementUrl = `https://leaguehub.ca/app/announcements/${encodeURIComponent(input.announcementId)}`;
  const subject = `${input.isPinned ? "Pinned: " : ""}${title}`;
  const text = [
    greeting,
    "",
    `${authorName} posted a new ${audience.toLowerCase()} announcement in ${organizationName}.`,
    "",
    title,
    "",
    body,
    "",
    `Open announcement: ${announcementUrl}`,
    "",
    "This inbox is not monitored. Open League Hub to view the announcement and continue in the app.",
    "",
    "League Hub",
  ].join("\n");

  const safeGreeting = escapeHtml(greeting);
  const safeAuthor = escapeHtml(authorName);
  const safeOrganization = escapeHtml(organizationName);
  const safeAudience = escapeHtml(audience);
  const safeTitle = escapeHtml(title);
  const safeBody = escapeHtml(body).replace(/\r?\n/g, "<br>");
  const safeUrl = escapeHtml(announcementUrl);
  const html = `<!doctype html><html><body style="margin:0;background:#f2f6fa;font-family:Arial,sans-serif;color:#061a33"><main style="max-width:640px;margin:32px auto;background:#fff;border:1px solid #d9e5f1;border-radius:20px;overflow:hidden"><div style="background:#06182c;padding:24px 28px;color:#fff"><p style="margin:0;font-size:13px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#64e0dc">League Hub</p><h1 style="margin:10px 0 0;font-size:25px;line-height:1.25">${safeTitle}</h1></div><div style="padding:28px"><p style="margin:0 0 16px">${safeGreeting}</p><p style="margin:0 0 20px;line-height:1.6"><strong>${safeAuthor}</strong> posted a new ${safeAudience.toLowerCase()} announcement in <strong>${safeOrganization}</strong>.</p><div style="margin:22px 0;padding:20px;border-radius:14px;background:#f5f9fc;border:1px solid #d9e5f1;line-height:1.65">${safeBody}</div><p style="margin:24px 0"><a href="${safeUrl}" style="display:inline-block;background:#087e91;color:#fff;text-decoration:none;font-weight:800;padding:13px 20px;border-radius:12px">Open announcement in League Hub</a></p><p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#59708e">This inbox is not monitored. Open League Hub to view the announcement and continue in the app.</p></div></main></body></html>`;

  return {subject, text, html};
}

function resendErrorName(responseBody: string): string | null {
  try {
    const parsed = JSON.parse(responseBody) as {
      name?: unknown;
      error?: {name?: unknown};
    };
    const rawName = typeof parsed.name === "string" ?
      parsed.name : parsed.error?.name;
    if (typeof rawName !== "string") return null;
    const name = rawName.trim().toLowerCase();
    return /^[a-z0-9_]{1,64}$/.test(name) ? name : null;
  } catch {
    return null;
  }
}

export function classifyAnnouncementDeliveryFailure(
  status: number | null,
  responseBody = "",
): AnnouncementDeliveryFailure {
  if (status === null) {
    return {
      retryable: true,
      deliveryStatus: "retrying",
      code: "network_error",
    };
  }

  const providerCode = resendErrorName(responseBody);
  const retryable = status === 429 || status >= 500 ||
    (status === 409 && providerCode === "concurrent_idempotent_requests");
  return {
    retryable,
    deliveryStatus: retryable ? "retrying" : "failed",
    code: providerCode ?? `http_${status}`,
  };
}
