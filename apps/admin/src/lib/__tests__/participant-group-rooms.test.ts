import { describe, expect, it } from "vitest";
import type { AppUser, ChatRoom } from "../types";
import {
  isParticipantGroupRoom,
  participantGroupMemberOptions,
  participantIdsChanged
} from "../participant-group-rooms";

const user = (patch: Partial<AppUser> = {}): AppUser => ({
  id: "staff-1",
  email: "staff@example.com",
  displayName: "Staff Member",
  role: "staff",
  orgId: "org-1",
  hubIds: [],
  leagueIds: [],
  teamIds: [],
  isActive: true,
  ...patch
});

const room = (patch: Partial<ChatRoom> = {}): ChatRoom => ({
  id: "room-1",
  orgId: "org-1",
  name: "Leadership",
  type: "event",
  roomPurpose: "group",
  accessMode: "participants",
  participants: ["staff-1", "admin-1"],
  isArchived: false,
  ...patch
});

describe("participant-only Group Chats", () => {
  it("recognizes only the explicit participant room contract", () => {
    expect(isParticipantGroupRoom(room())).toBe(true);
    expect(isParticipantGroupRoom(room({ accessMode: "scope" }))).toBe(false);
    expect(isParticipantGroupRoom(room({ roomPurpose: "event" }))).toBe(false);
    expect(isParticipantGroupRoom(room({ isArchived: true }))).toBe(false);
  });

  it("offers every active same-organization user regardless of assignments or role", () => {
    const options = participantGroupMemberOptions([
      user({ id: "assigned", displayName: "Assigned Staff", teamIds: ["team-1"] }),
      user({ id: "owner", displayName: "Owner", role: "platformOwner" }),
      user({ id: "manager", displayName: "Manager", role: "managerAdmin", hubIds: ["hub-1"] }),
      user({ id: "inactive", displayName: "Inactive", isActive: false }),
      user({ id: "other-org", displayName: "Other", orgId: "org-2" })
    ], "org-1", []);

    expect(options.map((option) => option.id)).toEqual(["assigned", "manager", "owner"]);
    expect(options.every((option) => option.isEligible)).toBe(true);
  });

  it("keeps inactive or missing existing participants visible for removal", () => {
    const options = participantGroupMemberOptions([
      user({ id: "active", displayName: "Active" }),
      user({ id: "inactive", displayName: "Inactive", isActive: false })
    ], "org-1", ["inactive", "missing"]);
    expect(options.map((option) => option.id)).toEqual(["active", "inactive", "missing"]);
    expect(options.find((option) => option.id === "inactive")?.isEligible).toBe(false);
    expect(options.find((option) => option.id === "missing")?.isKnown).toBe(false);
  });

  it("detects participant changes without depending on order", () => {
    expect(participantIdsChanged(["a", "b"], ["b", "a"])).toBe(false);
    expect(participantIdsChanged(["a", "b"], ["a", "c"])).toBe(true);
  });
});
