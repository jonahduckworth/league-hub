export const inquiryTypes = ["pricing", "demo", "general"] as const;

export type InquiryType = (typeof inquiryTypes)[number];

export type LandingContact = {
  inquiryType: InquiryType;
  name: string;
  email: string;
  organization: string;
  role: string;
  teamCount: string;
  message: string;
};

type ParseResult =
  | {ok: true; contact: LandingContact}
  | {ok: false; reason: string; isBot?: boolean};

const teamCounts = new Set(["", "1-10", "11-30", "31-75", "76+"]);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function clean(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.replace(/\r\n/g, "\n").trim();
  if (normalized.length > maxLength) return null;
  return normalized;
}

export function parseLandingContact(
  value: unknown,
  now = Date.now(),
): ParseResult {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {ok: false, reason: "Invalid request."};
  }

  const record = value as Record<string, unknown>;
  const website = clean(record.website, 200);
  if (website == null) return {ok: false, reason: "Invalid request."};
  if (website.length > 0) return {ok: false, reason: "Rejected.", isBot: true};

  const startedAt = record.startedAt;
  if (typeof startedAt !== "number" || !Number.isFinite(startedAt)) {
    return {ok: false, reason: "Please try again."};
  }
  const elapsed = now - startedAt;
  if (elapsed < 1800 || elapsed > 60 * 60 * 1000) {
    return {ok: false, reason: "Please try again."};
  }

  const inquiryType = clean(record.inquiryType, 20);
  const name = clean(record.name, 120);
  const email = clean(record.email, 254)?.toLowerCase() ?? null;
  const organization = clean(record.organization, 160);
  const role = clean(record.role, 120);
  const teamCount = clean(record.teamCount, 20);
  const message = clean(record.message, 3000);

  if (!inquiryTypes.includes(inquiryType as InquiryType)) {
    return {ok: false, reason: "Select a valid inquiry type."};
  }
  if (name == null || name.length < 2) {
    return {ok: false, reason: "Enter your name."};
  }
  if (email == null || !emailPattern.test(email)) {
    return {ok: false, reason: "Enter a valid email address."};
  }
  if (organization == null || organization.length < 2) {
    return {ok: false, reason: "Enter your league or organization."};
  }
  if (role == null || teamCount == null || !teamCounts.has(teamCount)) {
    return {ok: false, reason: "Check the optional details."};
  }
  if (message == null || message.length < 10) {
    return {ok: false, reason: "Tell us a little more about what you need."};
  }

  return {
    ok: true,
    contact: {
      inquiryType: inquiryType as InquiryType,
      name,
      email,
      organization,
      role,
      teamCount,
      message,
    },
  };
}

export function allowedLandingOrigin(origin: string | undefined): string | null {
  if (!origin) return null;

  try {
    const url = new URL(origin);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    const host = url.hostname.toLowerCase();

    if (
      host === "leaguehub.ca" ||
      host === "www.leaguehub.ca" ||
      host === "league-hub-marketing.web.app" ||
      host === "league-hub-marketing.firebaseapp.com"
    ) {
      return url.origin;
    }
    if (
      (host === "localhost" || host === "127.0.0.1") &&
      url.protocol === "http:"
    ) {
      return url.origin;
    }
  } catch {
    return null;
  }

  return null;
}

export function inquiryTypeLabel(type: InquiryType): string {
  switch (type) {
    case "pricing": return "Pricing";
    case "demo": return "Product demo";
    case "general": return "General question";
  }
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

export function landingContactEmail(contact: LandingContact): {
  subject: string;
  text: string;
  html: string;
} {
  const label = inquiryTypeLabel(contact.inquiryType);
  const details = [
    ["Name", contact.name],
    ["Email", contact.email],
    ["Organization", contact.organization],
    ["Role", contact.role || "Not provided"],
    ["Teams", contact.teamCount || "Not provided"],
    ["Inquiry", label],
  ];
  const text = [
    `New League Hub ${label.toLowerCase()} inquiry`,
    "",
    ...details.map(([key, detail]) => `${key}: ${detail}`),
    "",
    "Message:",
    contact.message,
  ].join("\n");
  const rows = details
    .map(([key, detail]) => `<tr><th align="left" style="padding:6px 14px 6px 0;color:#59708e">${escapeHtml(key)}</th><td style="padding:6px 0;color:#061a33">${escapeHtml(detail)}</td></tr>`)
    .join("");
  const html = `<!doctype html><html><body style="font-family:Arial,sans-serif;background:#f4f8fc;padding:28px"><main style="max-width:640px;margin:auto;background:#fff;border-radius:18px;padding:28px;border:1px solid #d9e5f1"><p style="color:#087e91;font-weight:700;letter-spacing:.08em;text-transform:uppercase">League Hub</p><h1 style="color:#061a33;font-size:24px">New ${escapeHtml(label)} inquiry</h1><table style="border-collapse:collapse">${rows}</table><h2 style="color:#061a33;font-size:17px;margin-top:24px">Message</h2><p style="white-space:pre-wrap;line-height:1.6;color:#28415f">${escapeHtml(contact.message)}</p></main></body></html>`;

  return {
    subject: `[League Hub] ${label} — ${contact.organization}`,
    text,
    html,
  };
}
