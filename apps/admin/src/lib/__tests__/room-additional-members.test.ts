import { describe, expect, it } from "vitest";
import type { AppUser, ChatRoom } from "../types";
import {
  additionalRoomMemberOptions,
  canEditAdditionalRoomMembers,
  isAdditionalRoomMemberCandidate,
  roomSupportsAdditionalMembers
} from "../room-additional-members";

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
  name: "Room",
  type: "league",
  teamId: "team-1",
  participants: [],
  isArchived: false,
  ...patch
});

describe("room-specific additional members", () => {
  it("limits editing to active Platform Owners and Super Admins", () => {
    expect(canEditAdditionalRoomMembers(user({ role: "platformOwner" }))).toBe(true);
    expect(canEditAdditionalRoomMembers(user({ role: "superAdmin" }))).toBe(true);
    expect(canEditAdditionalRoomMembers(user({ role: "managerAdmin" }))).toBe(false);
    expect(canEditAdditionalRoomMembers(user({ role: "staff" }))).toBe(false);
    expect(canEditAdditionalRoomMembers(user({ role: "superAdmin", isActive: false }))).toBe(false);
  });

  it("supports active Team Rooms and Event Rooms only", () => {
    expect(roomSupportsAdditionalMembers(room())).toBe(true);
    expect(roomSupportsAdditionalMembers(room({ type: "event", teamId: null }))).toBe(true);
    expect(roomSupportsAdditionalMembers(room({ type: "event", roomPurpose: "group", teamId: null }))).toBe(false);
    expect(roomSupportsAdditionalMembers(room({ type: "league", teamId: null, hubId: "hub-1" }))).toBe(false);
    expect(roomSupportsAdditionalMembers(room({ type: "direct", teamId: null }))).toBe(false);
    expect(roomSupportsAdditionalMembers(room({ isArchived: true }))).toBe(false);
  });

  it("only offers active same-org non-admin users without Team or Hub assignments", () => {
    expect(isAdditionalRoomMemberCandidate(user(), "org-1")).toBe(true);
    expect(isAdditionalRoomMemberCandidate(user({ role: "managerAdmin" }), "org-1")).toBe(true);
    expect(isAdditionalRoomMemberCandidate(user({ role: "superAdmin" }), "org-1")).toBe(false);
    expect(isAdditionalRoomMemberCandidate(user({ role: "platformOwner" }), "org-1")).toBe(false);
    expect(isAdditionalRoomMemberCandidate(user({ isActive: false }), "org-1")).toBe(false);
    expect(isAdditionalRoomMemberCandidate(user({ orgId: "org-2" }), "org-1")).toBe(false);
    expect(isAdditionalRoomMemberCandidate(user({ hubIds: ["hub-1"] }), "org-1")).toBe(false);
    expect(isAdditionalRoomMemberCandidate(user({ teamIds: ["team-1"] }), "org-1")).toBe(false);
  });

  it("keeps existing ineligible and missing members visible for removal", () => {
    const options = additionalRoomMemberOptions([
      user({ id: "eligible", displayName: "Eligible" }),
      user({ id: "assigned", displayName: "Assigned", teamIds: ["team-1"] }),
      user({ id: "other-org", displayName: "Other", orgId: "org-2" })
    ], "org-1", ["assigned", "missing"]);

    expect(options.map((option) => option.id)).toEqual(["assigned", "eligible", "missing"]);
    expect(options.find((option) => option.id === "assigned")?.isEligible).toBe(false);
    expect(options.find((option) => option.id === "missing")?.isKnown).toBe(false);
  });
});
