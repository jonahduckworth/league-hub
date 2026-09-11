import { describe, expect, it } from "vitest";
import { demoData } from "../demo-data";
import { activePendingInvitations, resendableExpiredInvitations } from "../invitations";

describe("activePendingInvitations", () => {
  it("returns only unexpired pending invitations with no active account", () => {
    const now = Date.parse("2026-08-12T12:00:00.000Z");
    const base = demoData.invitations[0];
    const invitations = [
      {...base, id: "valid", expiresAt: "2026-08-13T12:00:00.000Z"},
      {...base, id: "expired", expiresAt: "2026-08-11T12:00:00.000Z"},
      {...base, id: "legacy", expiresAt: undefined},
      {...base, id: "accepted", status: "accepted" as const},
      {...base, id: "active-user", email: demoData.users[0].email},
    ];

    expect(activePendingInvitations({
      users: demoData.users,
      invitations,
    }, now).map((invite) => invite.id)).toEqual(["valid"]);
  });
});

describe("resendableExpiredInvitations", () => {
  it("returns the latest expired invitation per email", () => {
    const now = Date.parse("2026-08-12T12:00:00.000Z");
    const base = demoData.invitations[0];
    const invitations = [
      {...base, id: "old-expired", email: "Coach@Example.com", createdAt: "2026-08-01T12:00:00.000Z", expiresAt: "2026-08-08T12:00:00.000Z"},
      {...base, id: "latest-expired", email: "coach@example.com", createdAt: "2026-08-02T12:00:00.000Z", expiresAt: "2026-08-09T12:00:00.000Z"},
      {...base, id: "manually-expired", email: "staff-new@example.com", createdAt: "2026-08-10T12:00:00.000Z", expiresAt: undefined, status: "expired" as const},
    ];

    expect(resendableExpiredInvitations({ users: demoData.users, invitations }, now)
      .map((invite) => invite.id)).toEqual(["manually-expired", "latest-expired"]);
  });

  it("excludes active members and emails with a current pending invitation", () => {
    const now = Date.parse("2026-08-12T12:00:00.000Z");
    const base = demoData.invitations[0];
    const invitations = [
      {...base, id: "expired-with-replacement", email: "coach@example.com", expiresAt: "2026-08-01T12:00:00.000Z"},
      {...base, id: "active-replacement", email: "coach@example.com", expiresAt: "2026-08-13T12:00:00.000Z"},
      {...base, id: "active-member", email: demoData.users[0].email, expiresAt: "2026-08-01T12:00:00.000Z"},
    ];

    expect(resendableExpiredInvitations({ users: demoData.users, invitations }, now)).toEqual([]);
  });
});
