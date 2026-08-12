const test = require("node:test");
const assert = require("node:assert/strict");

const {
  allowedLandingOrigin,
  escapeHtml,
  landingContactEmail,
  parseLandingContact,
  trustedClientIp,
} = require("../lib/landingContactLogic");

const now = 1_800_000_000_000;
const valid = {
  inquiryType: "pricing",
  name: "Taylor Smith",
  email: "Taylor@Example.com",
  organization: "North Valley Hockey",
  role: "Registrar",
  teamCount: "11-30",
  message: "We want one place for league communication and schedules.",
  website: "",
  startedAt: now - 10_000,
};

test("parses and normalizes a valid landing inquiry", () => {
  const result = parseLandingContact(valid, now);
  assert.equal(result.ok, true);
  assert.equal(result.contact.email, "taylor@example.com");
  assert.equal(result.contact.organization, "North Valley Hockey");
});

test("rejects invalid fields, oversized content, and suspicious timing", () => {
  assert.equal(parseLandingContact({...valid, email: "nope"}, now).ok, false);
  assert.equal(parseLandingContact({...valid, name: "x"}, now).ok, false);
  assert.equal(parseLandingContact({...valid, message: "x".repeat(3001)}, now).ok, false);
  assert.equal(parseLandingContact({...valid, startedAt: now - 200}, now).ok, false);
});

test("silently recognizes honeypot submissions", () => {
  const result = parseLandingContact({...valid, website: "spam.test"}, now);
  assert.deepEqual(result, {ok: false, reason: "Rejected.", isBot: true});
});

test("allows only production League Hub origins and local development", () => {
  assert.equal(allowedLandingOrigin("https://leaguehub.ca"), "https://leaguehub.ca");
  assert.equal(
    allowedLandingOrigin("https://league-hub-marketing.web.app"),
    "https://league-hub-marketing.web.app",
  );
  assert.equal(allowedLandingOrigin("http://localhost:3020"), "http://localhost:3020");
  assert.equal(allowedLandingOrigin("https://evil.example"), null);
  assert.equal(allowedLandingOrigin("javascript:alert(1)"), null);
});

test("uses Google's appended client IP instead of a forged X-Forwarded-For prefix", () => {
  assert.equal(
    trustedClientIp(
      "198.51.100.77, 203.0.113.25, 35.191.0.1",
      "10.0.0.2",
    ),
    "203.0.113.25",
  );
  assert.equal(
    trustedClientIp("203.0.113.25, 35.191.0.1", "10.0.0.2"),
    "203.0.113.25",
  );
  assert.equal(trustedClientIp("198.51.100.77", "10.0.0.2"), "10.0.0.2");
});

test("escapes requester content in the email while preserving plain text", () => {
  assert.equal(escapeHtml(`<img src=x onerror="bad">`), "&lt;img src=x onerror=&quot;bad&quot;&gt;");
  const message = landingContactEmail({...valid, email: "taylor@example.com"});
  assert.match(message.subject, /^\[League Hub\] Pricing/);
  assert.match(message.text, /Taylor Smith/);
  assert.doesNotMatch(message.html, /<script>/);
});
