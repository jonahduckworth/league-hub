import { describe, expect, it } from "vitest";
import { demoData } from "../demo-data";
import { buildHealthChecks } from "../health";

describe("buildHealthChecks", () => {
  it("reports good assignments when user references exist", () => {
    const checks = buildHealthChecks(demoData);
    expect(checks.find((check) => check.id === "assignments")).toMatchObject({
      severity: "good",
      value: "0 broken"
    });
  });

  it("flags broken team assignments", () => {
    const checks = buildHealthChecks({
      ...demoData,
      users: [
        ...demoData.users,
        {
          ...demoData.users[0],
          id: "broken",
          teamIds: ["missing-team"]
        }
      ]
    });
    expect(checks.find((check) => check.id === "assignments")?.severity).toBe("danger");
  });

  it("summarizes notification failures", () => {
    const checks = buildHealthChecks(demoData);
    expect(checks.find((check) => check.id === "notifications")).toMatchObject({
      severity: "warning",
      value: "1 failed"
    });
  });

  it("does not count pending invitations for active users", () => {
    const checks = buildHealthChecks({
      ...demoData,
      users: [
        ...demoData.users,
        {
          id: "accepted-user",
          email: "coach@example.com",
          displayName: "Coach Active",
          role: "managerAdmin",
          orgId: "org-demo",
          hubIds: ["hub-calgary"],
          leagueIds: ["league-winter"],
          teamIds: [],
          isActive: true
        }
      ]
    });

    expect(checks.find((check) => check.id === "invites")).toMatchObject({
      severity: "good",
      value: "0 pending"
    });
  });
});
