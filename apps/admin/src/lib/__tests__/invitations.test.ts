import { describe, expect, it } from "vitest";
import { demoData } from "../demo-data";
import { activePendingInvitations } from "../invitations";

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
