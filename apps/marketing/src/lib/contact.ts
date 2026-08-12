export const inquiryTypes = ["pricing", "demo", "general"] as const;

export type InquiryType = (typeof inquiryTypes)[number];

export type ContactPayload = {
  inquiryType: InquiryType;
  name: string;
  email: string;
  organization: string;
  role: string;
  teamCount: string;
  message: string;
  website: string;
  startedAt: number;
};

export function isContactPayload(value: unknown): value is ContactPayload {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  return (
    inquiryTypes.includes(data.inquiryType as InquiryType) &&
    typeof data.name === "string" &&
    data.name.trim().length >= 2 &&
    typeof data.email === "string" &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim()) &&
    typeof data.organization === "string" &&
    data.organization.trim().length >= 2 &&
    typeof data.role === "string" &&
    typeof data.teamCount === "string" &&
    typeof data.message === "string" &&
    data.message.trim().length >= 10 &&
    typeof data.website === "string" &&
    typeof data.startedAt === "number"
  );
}

export function inquiryLabel(type: InquiryType): string {
  switch (type) {
    case "pricing":
      return "Pricing inquiry";
    case "demo":
      return "Book a demo";
    case "general":
      return "General question";
  }
}
