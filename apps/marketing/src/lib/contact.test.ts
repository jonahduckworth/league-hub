import { describe, expect, it } from "vitest";
import { inquiryLabel, isContactPayload } from "./contact";

const validPayload = {
  inquiryType: "pricing",
  name: "Jordan Davis",
  email: "jordan@example.com",
  organization: "Premier League",
  role: "Director",
  teamCount: "31-75",
  message: "We would like to bring our teams into one app.",
  website: "",
  startedAt: Date.now() - 5000,
};

describe("contact payload", () => {
  it("accepts a complete inquiry", () => {
    expect(isContactPayload(validPayload)).toBe(true);
  });

  it("rejects malformed contact data", () => {
    expect(isContactPayload({ ...validPayload, email: "not-an-email" })).toBe(false);
    expect(isContactPayload({ ...validPayload, message: "short" })).toBe(false);
    expect(isContactPayload({ ...validPayload, inquiryType: "unknown" })).toBe(false);
  });

  it("provides human-readable inquiry labels", () => {
    expect(inquiryLabel("pricing")).toBe("Pricing inquiry");
    expect(inquiryLabel("demo")).toBe("Book a demo");
    expect(inquiryLabel("general")).toBe("General question");
  });
});
