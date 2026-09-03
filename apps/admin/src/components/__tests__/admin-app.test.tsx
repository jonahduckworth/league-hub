import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const adminDataMocks = vi.hoisted(() => ({
  reloadStructure: vi.fn(),
  sendChatRoomMessage: vi.fn(),
  setSelectedOrgId: vi.fn(),
  useChatRoomMessages: vi.fn(),
  useAdminData: vi.fn()
}));

const storageMocks = vi.hoisted(() => ({
  deleteObject: vi.fn(),
  getDownloadURL: vi.fn(),
  ref: vi.fn(),
  uploadBytes: vi.fn()
}));

vi.mock("@/lib/firebase", () => ({
  auth: null,
  db: null,
  demoMode: true,
  firebaseProjectId: "league-hub-test",
  hasFirebaseConfig: () => true,
  storage: { bucket: "test" }
}));

vi.mock("@/lib/firestore", () => ({
  sendChatRoomMessage: adminDataMocks.sendChatRoomMessage,
  useAdminData: adminDataMocks.useAdminData,
  useChatRoomMessages: adminDataMocks.useChatRoomMessages
}));

vi.mock("@/lib/callables", () => ({
  callAdmin: vi.fn()
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn(),
  signInWithEmailAndPassword: vi.fn(),
  signOut: vi.fn()
}));

vi.mock("firebase/firestore", () => ({
  collection: vi.fn(),
  doc: vi.fn(),
  getDoc: vi.fn()
}));

vi.mock("firebase/storage", () => ({
  deleteObject: storageMocks.deleteObject,
  getDownloadURL: storageMocks.getDownloadURL,
  ref: storageMocks.ref,
  uploadBytes: storageMocks.uploadBytes
}));

import {
  AdminApp,
  ChatRoomDrawer,
  CreateEventRoomDrawer,
  CreateInviteDrawer,
  UserAccessEditor
} from "../admin-app";
import { demoData, demoUser } from "@/lib/demo-data";

const secondOrganization = {
  ...demoData.orgs[0],
  id: "org-east",
  name: "Eastern Soccer Association"
};

describe("AdminApp operations shell", () => {
  beforeEach(() => {
    window.history.replaceState(null, "", "/admin");
    adminDataMocks.reloadStructure.mockReset().mockResolvedValue(undefined);
    adminDataMocks.sendChatRoomMessage.mockReset().mockResolvedValue(undefined);
    adminDataMocks.setSelectedOrgId.mockReset();
    adminDataMocks.useChatRoomMessages.mockReset().mockReturnValue({
      messages: [],
      loading: false,
      error: undefined,
      retry: vi.fn()
    });
    adminDataMocks.useAdminData.mockReset().mockReturnValue({
      data: {
        ...demoData,
        orgs: [...demoData.orgs, secondOrganization]
      },
      error: undefined,
      loading: false,
      reloadStructure: adminDataMocks.reloadStructure,
      selectedOrgId: "org-demo",
      setSelectedOrgId: adminDataMocks.setSelectedOrgId
    });
    storageMocks.deleteObject.mockReset().mockResolvedValue(undefined);
    storageMocks.getDownloadURL.mockReset().mockResolvedValue("https://cdn.example.com/showcase.png");
    storageMocks.ref.mockReset().mockImplementation((_storage, path) => ({ path }));
    storageMocks.uploadBytes.mockReset().mockResolvedValue(undefined);
  });

  afterEach(() => {
    cleanup();
    document.body.style.overflow = "";
  });

  it("renders the operations landmarks and equivalent desktop and mobile navigation", () => {
    render(<AdminApp />);

    expect(screen.getByRole("main")).toBeTruthy();
    expect(screen.getByRole("heading", { level: 1, name: "Overview" })).toBeTruthy();
    expect(screen.getByText("Admin workspace")).toBeTruthy();
    expect(screen.getByText("Demo workspace")).toBeTruthy();

    const sectionNavigations = screen.getAllByRole("navigation", { name: "Admin sections" });
    expect(sectionNavigations).toHaveLength(2);

    for (const section of ["Overview", "People", "Structure", "Schedule", "Chat Rooms", "Announcements", "Policies"]) {
      expect(within(sectionNavigations[0]).getByRole("button", { name: section })).toBeTruthy();
    }
    for (const section of ["People", "Structure", "Schedule", "Chat Rooms"]) {
      expect(within(sectionNavigations[1]).getByRole("button", { name: section })).toBeTruthy();
    }
    expect(within(sectionNavigations[1]).getByRole("button", { name: "More sections" })).toBeTruthy();
    expect(within(sectionNavigations[1]).queryByRole("button", { name: "Announcements" })).toBeNull();
    expect(within(sectionNavigations[1]).queryByRole("button", { name: "Policies" })).toBeNull();
    expect(within(sectionNavigations[1]).queryByRole("button", { name: "Overview" })).toBeNull();
    expect(screen.getAllByRole("button", { name: "Overview" })).toHaveLength(2);
    expect(within(sectionNavigations[0]).getByRole("button", { name: "Overview" }).getAttribute("aria-current")).toBe("page");
    expect(within(sectionNavigations[0]).getByRole("button", { name: "People" }).getAttribute("aria-current")).toBeNull();
  });

  it("shows chat room coverage and keeps private rooms read-only", async () => {
    window.history.replaceState(null, "", "/admin#chats");
    adminDataMocks.useAdminData.mockReturnValue({
      data: {
        ...demoData,
        orgs: [...demoData.orgs, secondOrganization],
        chatRooms: [
          ...demoData.chatRooms,
          {
            id: "hub-room",
            orgId: "org-demo",
            name: "Calgary - General",
            type: "league",
            leagueId: "league-winter",
            hubId: "hub-calgary",
            participants: [],
            isArchived: false
          },
          {
            id: "team-room",
            orgId: "org-demo",
            name: "Calgary U11 AA - General",
            type: "league",
            leagueId: "league-winter",
            hubId: "hub-calgary",
            teamId: "team-u11-aa",
            participants: [],
            isArchived: false
          },
          {
            id: "direct-room",
            orgId: "org-demo",
            name: "Private conversation",
            type: "direct",
            participants: ["demo-owner", "admin-1"],
            isArchived: false
          },
          {
            id: "showcase-room",
            orgId: "org-demo",
            name: "Provincial Showcase",
            type: "event",
            roomPurpose: "event",
            leagueId: "league-winter",
            hubId: "__multi_team__",
            teamId: "__multi_team__",
            hubIds: ["hub-calgary", "hub-reddeer"],
            teamIds: ["team-u11-aa", "team-u13-a"],
            participants: [],
            isArchived: false
          }
        ]
      },
      error: undefined,
      loading: false,
      reloadStructure: adminDataMocks.reloadStructure,
      selectedOrgId: "org-demo",
      setSelectedOrgId: adminDataMocks.setSelectedOrgId
    });

    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 1, name: "Chat Rooms" })).toBeTruthy();
    expect(screen.getAllByText("1/2")).toHaveLength(2);
    expect(screen.getByRole("button", { name: "Review Room Setup" })).toBeTruthy();
    expect(screen.getByText("2 teams")).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: "Open Provincial Showcase chat room details" }));
    const showcaseDrawer = await screen.findByRole("dialog", { name: "Provincial Showcase" });
    expect(within(showcaseDrawer).getAllByText("Event room")).toHaveLength(2);
    expect(within(showcaseDrawer).getByText("Calgary, Red Deer")).toBeTruthy();
    expect(within(showcaseDrawer).getByText("Calgary U11 AA, Red Deer U13 A")).toBeTruthy();
    fireEvent.click(within(showcaseDrawer).getByRole("button", { name: "Close drawer" }));
    await waitFor(() => expect(screen.queryByRole("dialog", { name: "Provincial Showcase" })).toBeNull());
    fireEvent.click(screen.getByRole("button", { name: "Open Private conversation chat room details" }));
    const drawer = await screen.findByRole("dialog", { name: "Private conversation" });
    expect(within(drawer).getByText(/private conversations/i)).toBeTruthy();
    expect(within(drawer).queryByRole("button", { name: /save changes/i })).toBeNull();
    expect(within(drawer).queryByRole("button", { name: /archive room/i })).toBeNull();

    fireEvent.click(within(drawer).getByRole("button", { name: "Close drawer" }));
    await waitFor(() => expect(screen.queryByRole("dialog", { name: "Private conversation" })).toBeNull());
    fireEvent.click(screen.getByRole("button", { name: "Open Calgary U11 AA - General chat room details" }));
    const managedDrawer = await screen.findByRole("dialog", { name: "Calgary U11 AA - General" });
    expect(within(managedDrawer).getByText(/managed from Structure/i)).toBeTruthy();
    expect(within(managedDrawer).getByRole("heading", { name: "Conversation" })).toBeTruthy();
    expect(within(managedDrawer).getAllByText("No messages yet").length).toBeGreaterThan(0);
    expect(within(managedDrawer).getByRole("textbox", { name: "Post a message" })).toBeTruthy();
    expect(within(managedDrawer).queryByRole("button", { name: /save changes/i })).toBeNull();
    expect(within(managedDrawer).queryByRole("textbox", { name: "Room name" })).toBeNull();
    fireEvent.click(within(managedDrawer).getByRole("button", { name: "Archive room" }));
    const cancelArchive = within(managedDrawer).getByRole("button", { name: "Cancel" });
    await waitFor(() => expect(document.activeElement).toBe(cancelArchive));
  });

  it("creates a cross-Hub Event Room with an optional photo", async () => {
    const runAction = vi.fn().mockImplementation(async (name: string) => {
      if (name === "createMultiTeamEventRoom") {
        return { ok: true, data: { roomId: "showcase-new" } };
      }
      return { ok: true, data: {} };
    });
    const onClose = vi.fn();

    render(
      <CreateEventRoomDrawer
        open
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={onClose}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "New Event Room" });
    fireEvent.change(within(drawer).getByRole("textbox", { name: /Room name/i }), {
      target: { value: "Provincial Showcase" }
    });
    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Calgary U11 AA/i }));
    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Red Deer U13 A/i }));
    expect(within(drawer).getByText("2 teams across 2 Hubs")).toBeTruthy();

    const photo = new File(["photo"], "Provincial Showcase.png", { type: "image/png" });
    fireEvent.change(within(drawer).getByLabelText("Event Room photo"), {
      target: { files: [photo] }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Create Event Room" }));

    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(runAction).toHaveBeenNthCalledWith(1, "createMultiTeamEventRoom", {
      name: "Provincial Showcase",
      leagueId: "league-winter",
      teams: [
        { hubId: "hub-calgary", teamId: "team-u11-aa" },
        { hubId: "hub-reddeer", teamId: "team-u13-a" }
      ],
      roomIconName: "event"
    });
    expect(storageMocks.ref).toHaveBeenCalledWith(
      expect.anything(),
      expect.stringMatching(/^orgs\/org-demo\/chat\/showcase-new\/room-images\/demo-owner\/\d+_Provincial_Showcase\.png$/)
    );
    expect(storageMocks.uploadBytes).toHaveBeenCalledWith(
      expect.anything(),
      photo,
      { contentType: "image/png" }
    );
    expect(runAction).toHaveBeenNthCalledWith(2, "adminUpdateChatRoom", {
      roomId: "showcase-new",
      patch: {
        roomIconName: null,
        roomImageUrl: "https://cdn.example.com/showcase.png"
      }
    });
  });

  it("retains the upload when a created room's photo update result is ambiguous", async () => {
    const runAction = vi.fn().mockImplementation(async (name: string) => {
      if (name === "createMultiTeamEventRoom") {
        return { ok: true, data: { roomId: "showcase-partial" } };
      }
      return { ok: false, error: "Photo update failed" };
    });
    const onClose = vi.fn();

    render(
      <CreateEventRoomDrawer
        open
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={onClose}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "New Event Room" });
    fireEvent.change(within(drawer).getByRole("textbox", { name: /Room name/i }), {
      target: { value: "Provincial Showcase" }
    });
    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Calgary U11 AA/i }));
    fireEvent.change(within(drawer).getByLabelText("Event Room photo"), {
      target: { files: [new File(["photo"], "showcase.png", { type: "image/png" })] }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Create Event Room" }));

    expect(await within(drawer).findByText("The Event Room has been created.")).toBeTruthy();
    expect(within(drawer).getByRole("alert").textContent).toMatch(/could not be confirmed/i);
    expect(within(drawer).queryByRole("button", { name: "Create Event Room" })).toBeNull();
    expect(storageMocks.deleteObject).not.toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
  });

  it("cleans up only when the room photo upload itself fails", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: true, data: { roomId: "showcase-upload-failed" } });
    storageMocks.uploadBytes.mockRejectedValueOnce(new Error("Upload failed"));

    render(
      <CreateEventRoomDrawer
        open
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={vi.fn()}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "New Event Room" });
    fireEvent.change(within(drawer).getByRole("textbox", { name: /Room name/i }), {
      target: { value: "Provincial Showcase" }
    });
    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Calgary U11 AA/i }));
    fireEvent.change(within(drawer).getByLabelText("Event Room photo"), {
      target: { files: [new File(["photo"], "showcase.png", { type: "image/png" })] }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Create Event Room" }));

    expect(await within(drawer).findByText(/photo could not be uploaded/i)).toBeTruthy();
    expect(storageMocks.deleteObject).toHaveBeenCalledTimes(1);
    expect(runAction).toHaveBeenCalledTimes(1);
  });

  it("replaces and removes an existing Event Room photo", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: true, data: {} });
    const room = {
      id: "showcase-room",
      orgId: "org-demo",
      name: "Provincial Showcase",
      type: "event" as const,
      roomPurpose: "event" as const,
      leagueId: "league-winter",
      hubId: "__multi_team__",
      teamId: "__multi_team__",
      hubIds: ["hub-calgary", "hub-reddeer"],
      teamIds: ["team-u11-aa", "team-u13-a"],
      participants: [],
      isArchived: false,
      roomImageUrl: null
    };

    render(
      <ChatRoomDrawer
        room={room}
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={vi.fn()}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "Provincial Showcase" });
    const photo = new File(["replacement"], "showcase.webp", { type: "image/webp" });
    fireEvent.change(within(drawer).getByLabelText("Room photo file"), {
      target: { files: [photo] }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Save photo" }));

    await waitFor(() => expect(runAction).toHaveBeenCalledWith("adminUpdateChatRoom", {
      roomId: "showcase-room",
      patch: {
        roomIconName: null,
        roomImageUrl: "https://cdn.example.com/showcase.png"
      }
    }));
    fireEvent.click(within(drawer).getByRole("button", { name: "Remove photo" }));
    await waitFor(() => expect(runAction).toHaveBeenCalledWith("adminUpdateChatRoom", {
      roomId: "showcase-room",
      patch: { roomIconName: "event", roomImageUrl: null }
    }));
  });

  it("adds and removes teams from an existing Event Room with removal confirmation", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: true, data: {} });
    const room = {
      id: "showcase-room",
      orgId: "org-demo",
      name: "Provincial Showcase",
      type: "event" as const,
      roomPurpose: "event" as const,
      leagueId: "league-winter",
      hubId: "__multi_team__",
      teamId: "__multi_team__",
      hubIds: ["hub-calgary"],
      teamIds: ["team-u11-aa"],
      participants: [],
      isArchived: false,
      roomImageUrl: null
    };

    render(
      <ChatRoomDrawer
        room={room}
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={vi.fn()}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "Provincial Showcase" });
    expect(within(drawer).getByText(/complete message history/i)).toBeTruthy();
    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Red Deer U13 A/i }));
    fireEvent.click(within(drawer).getByRole("button", { name: "Save team access" }));

    await waitFor(() => expect(runAction).toHaveBeenCalledWith("adminUpdateEventRoomAudience", {
      roomId: "showcase-room",
      expectedTeamIds: ["team-u11-aa"],
      teams: [
        { hubId: "hub-calgary", teamId: "team-u11-aa" },
        { hubId: "hub-reddeer", teamId: "team-u13-a" }
      ]
    }));
    expect(await within(drawer).findByText(/Message history was preserved/i)).toBeTruthy();

    fireEvent.click(within(drawer).getByRole("checkbox", { name: /Calgary U11 AA/i }));
    fireEvent.click(within(drawer).getByRole("button", { name: "Save team access" }));
    expect(within(drawer).getByText(/Remove access for 1 team/i)).toBeTruthy();
    expect(runAction).toHaveBeenCalledTimes(1);
    fireEvent.click(within(drawer).getByRole("button", { name: "Confirm removal" }));

    await waitFor(() => expect(runAction).toHaveBeenLastCalledWith("adminUpdateEventRoomAudience", {
      roomId: "showcase-room",
      expectedTeamIds: ["team-u11-aa", "team-u13-a"],
      teams: [{ hubId: "hub-reddeer", teamId: "team-u13-a" }]
    }));
  });

  it("does not expose Event Room team editing to managers", async () => {
    const manager = { ...demoUser, role: "managerAdmin" as const };
    const room = {
      id: "showcase-room",
      orgId: "org-demo",
      name: "Provincial Showcase",
      type: "event" as const,
      roomPurpose: "event" as const,
      leagueId: "league-winter",
      hubIds: ["hub-calgary"],
      teamIds: ["team-u11-aa"],
      participants: [],
      isArchived: false
    };

    render(
      <ChatRoomDrawer
        room={room}
        data={demoData}
        currentUser={manager}
        runAction={vi.fn()}
        onClose={vi.fn()}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "Provincial Showcase" });
    expect(within(drawer).queryByRole("button", { name: "Save team access" })).toBeNull();
    expect(within(drawer).queryByText(/complete message history/i)).toBeNull();
  });

  it("retains an uploaded replacement when its room update result is ambiguous", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: false, error: "Audit write failed" });
    const room = {
      id: "showcase-room",
      orgId: "org-demo",
      name: "Provincial Showcase",
      type: "event" as const,
      roomPurpose: "event" as const,
      leagueId: "league-winter",
      hubId: "__multi_team__",
      teamId: "__multi_team__",
      hubIds: ["hub-calgary", "hub-reddeer"],
      teamIds: ["team-u11-aa", "team-u13-a"],
      participants: [],
      isArchived: false,
      roomImageUrl: null
    };

    render(
      <ChatRoomDrawer
        room={room}
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={vi.fn()}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "Provincial Showcase" });
    fireEvent.change(within(drawer).getByLabelText("Room photo file"), {
      target: { files: [new File(["replacement"], "showcase.webp", { type: "image/webp" })] }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Save photo" }));

    expect(await within(drawer).findByText(/photo update could not be confirmed/i)).toBeTruthy();
    expect(storageMocks.deleteObject).not.toHaveBeenCalled();
    expect((within(drawer).getByLabelText("Room photo file") as HTMLInputElement).disabled).toBe(true);
    expect(within(drawer).queryByRole("button", { name: "Save photo" })).toBeNull();
  });

  it("loads a shared-room conversation and posts as the signed-in administrator", async () => {
    window.history.replaceState(null, "", "/admin#chats");
    adminDataMocks.useChatRoomMessages.mockReturnValue({
      messages: [
        {
          id: "message-1",
          chatRoomId: "room-1",
          senderId: "member-1",
          senderName: "Taylor Member",
          text: "Practice moves to 7 PM.",
          createdAt: new Date().toISOString(),
          deleted: false,
          readBy: []
        }
      ],
      loading: false,
      error: undefined,
      retry: vi.fn()
    });

    render(<AdminApp />);
    fireEvent.click(await screen.findByRole("button", { name: "Open Winter Hockey - General chat room details" }));
    const drawer = await screen.findByRole("dialog", { name: "Winter Hockey - General" });
    expect(within(drawer).getByText("Taylor Member")).toBeTruthy();
    expect(within(drawer).getByText("Practice moves to 7 PM.")).toBeTruthy();

    fireEvent.change(within(drawer).getByRole("textbox", { name: "Post a message" }), {
      target: { value: "Thanks — the schedule is updated." }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Send message" }));

    await waitFor(() => expect(adminDataMocks.sendChatRoomMessage).toHaveBeenCalledWith({
      orgId: "org-demo",
      roomId: "room-1",
      senderId: demoUser.id,
      senderName: demoUser.displayName,
      text: "Thanks — the schedule is updated."
    }));
  });

  it("explains automatic General chat creation in hub and team drawers", async () => {
    window.history.replaceState(null, "", "/admin#structure");
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "Structure" });
    fireEvent.click(screen.getAllByRole("button", { name: "Add hub" })[0]);
    const hubDrawer = await screen.findByRole("dialog", { name: "Add Hub" });
    expect(within(hubDrawer).getByRole("note")).toBeTruthy();
    expect(within(hubDrawer).getByText(/General chat room will be created automatically/i)).toBeTruthy();
    expect(within(hubDrawer).getByText(/name and logo stay synced with Structure/i)).toBeTruthy();

    fireEvent.click(within(hubDrawer).getByRole("button", { name: "Close drawer" }));
    fireEvent.click(screen.getAllByRole("button", { name: "Add team" })[0]);
    const teamDrawer = await screen.findByRole("dialog", { name: "Add Team" });
    expect(within(teamDrawer).getByRole("note")).toBeTruthy();
    expect(within(teamDrawer).getByText(/General chat room will be created automatically/i)).toBeTruthy();
  });

  it("shows native game data, sync health, and source controls in the schedule workspace", async () => {
    window.history.replaceState(null, "", "/admin#schedule");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 2, name: "RAMP schedule" })).toBeTruthy();
    expect(screen.getByText("Wolves HC")).toBeTruthy();
    expect(screen.getByText("Calgary Rockies")).toBeTruthy();
    expect(screen.getByText("RAMP game schedules are up to date.")).toBeTruthy();
    expect(screen.getByText("Season synced")).toBeTruthy();
    expect(screen.getByText("Season discovery")).toBeTruthy();
    expect(screen.getAllByText("12322").length).toBeGreaterThan(0);
    expect(screen.getByRole("button", { name: "Sync now" })).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: /results/i }));
    expect(await screen.findByText("Island HC")).toBeTruthy();
    expect(screen.getByText("Okanagan HC")).toBeTruthy();

    fireEvent.click(screen.getByText("RAMP source settings"));
    expect(screen.getByLabelText(/Season ID/)).toBeTruthy();
    expect(screen.getByText(/older team IDs are not required/i)).toBeTruthy();
    expect(screen.getByLabelText("17U division ID")).toBeTruthy();
    const autoDiscovery = screen.getByRole("checkbox", { name: "Automatically discover new JPHL seasons" });
    expect((autoDiscovery as HTMLInputElement).checked).toBe(true);
    expect(screen.getByText(/matches every configured team/i)).toBeTruthy();
    expect(screen.getByRole("button", { name: "Save source settings" })).toBeTruthy();
  });

  it("exposes labeled organization selectors for both responsive shell variants", () => {
    render(<AdminApp />);

    const organizationSelectors = screen.getAllByRole("combobox", { name: "Organization" });
    expect(organizationSelectors).toHaveLength(2);

    for (const selector of organizationSelectors) {
      expect((selector as HTMLSelectElement).value).toBe("org-demo");
      expect(within(selector).getByRole("option", { name: "Prairie Hockey League" })).toBeTruthy();
      expect(within(selector).getByRole("option", { name: "Eastern Soccer Association" })).toBeTruthy();
      fireEvent.change(selector, { target: { value: "org-east" } });
    }

    expect(adminDataMocks.setSelectedOrgId).toHaveBeenCalledTimes(2);
    expect(adminDataMocks.setSelectedOrgId).toHaveBeenNthCalledWith(1, "org-east");
    expect(adminDataMocks.setSelectedOrgId).toHaveBeenNthCalledWith(2, "org-east");
  });

  it("syncs section navigation with deep links, hash changes, and the overview route", async () => {
    window.history.replaceState(null, "", "/admin#people");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 1, name: "People" })).toBeTruthy();
    expect(window.location.hash).toBe("#people");

    fireEvent.click(screen.getAllByRole("button", { name: "Structure" })[0]);
    fireEvent(window, new Event("hashchange"));

    expect(await screen.findByRole("heading", { level: 1, name: "Structure" })).toBeTruthy();
    expect(window.location.hash).toBe("#structure");
    for (const button of screen.getAllByRole("button", { name: "Structure" })) {
      expect(button.getAttribute("aria-current")).toBe("page");
    }

    window.history.pushState(null, "", "/admin#policies");
    fireEvent(window, new PopStateEvent("popstate"));
    expect(await screen.findByRole("heading", { level: 1, name: "Policies" })).toBeTruthy();

    fireEvent.click(screen.getAllByRole("button", { name: "Overview" })[0]);
    await waitFor(() => {
      expect(screen.getByRole("heading", { level: 1, name: "Overview" })).toBeTruthy();
    });
    expect(window.location.hash).toBe("");
  });

  it("provides accessible member cards and keyboard-modal record drawers", async () => {
    window.history.replaceState(null, "", "/admin#people");
    adminDataMocks.useAdminData.mockReturnValue({
      data: {
        ...demoData,
        orgs: [...demoData.orgs, secondOrganization],
        users: demoData.users.map((user) => user.id === "admin-1" ? {
          ...user,
          title: "League administrator",
          phone: "403-555-0142"
        } : user)
      },
      error: undefined,
      loading: false,
      reloadStructure: adminDataMocks.reloadStructure,
      selectedOrgId: "org-demo",
      setSelectedOrgId: adminDataMocks.setSelectedOrgId
    });
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "People" });
    expect(screen.getByRole("heading", { level: 2, name: "People at Prairie Hockey League" })).toBeTruthy();
    fireEvent.change(screen.getByRole("textbox", { name: "Search members..." }), { target: { value: "403-555-0142" } });
    const memberButton = screen.getByRole("button", { name: "Open Avery Admin member details" });
    expect(within(memberButton).getByText("403-555-0142")).toBeTruthy();
    expect(within(memberButton).getByText("League administrator")).toBeTruthy();
    memberButton.focus();
    fireEvent.click(memberButton);

    const drawer = await screen.findByRole("dialog", { name: "Avery Admin" });
    expect(drawer.getAttribute("aria-modal")).toBe("true");
    expect(drawer.parentElement?.parentElement).toBe(document.body);
    expect(screen.getByTestId("drawer-scroll-region").className).toContain("min-h-0");
    expect(screen.getByTestId("drawer-scroll-region").className).toContain("overflow-y-auto");
    expect(within(drawer).getByRole("heading", { name: "Avery Admin" })).toBeTruthy();
    expect(within(drawer).getByText("403-555-0142")).toBeTruthy();
    expect(within(drawer).getByText("League administrator")).toBeTruthy();
    const closeButton = within(drawer).getByRole("button", { name: "Close drawer" });
    await waitFor(() => expect(document.activeElement).toBe(closeButton));

    fireEvent.keyDown(window, { key: "Escape" });
    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: "Avery Admin" })).toBeNull();
    });
    expect(document.activeElement).toBe(memberButton);
  });

  it("lets admins edit peer assignments while preserving peer role and status safety", async () => {
    const originalRole = demoUser.role;
    demoUser.role = "superAdmin";
    window.history.replaceState(null, "", "/admin#people");

    try {
      render(<AdminApp />);
      await screen.findByRole("heading", { level: 1, name: "People" });
      fireEvent.click(screen.getByRole("button", { name: "Open Avery Admin member details" }));

      const drawer = await screen.findByRole("dialog", { name: "Avery Admin" });
      expect(within(drawer).getByText(/Admins automatically have organization-wide access/)).toBeTruthy();
      expect(within(drawer).getByText(/Only a Platform Owner can change another Admin’s role/)).toBeTruthy();
      expect(within(drawer).queryByRole("combobox", { name: "Role" })).toBeNull();
      expect(within(drawer).queryByRole("button", { name: "Deactivate User" })).toBeNull();

      fireEvent.click(within(drawer).getByRole("button", { name: "Select all hubs & teams" }));
      await waitFor(() => {
        expect((within(drawer).getByRole("checkbox", { name: "Red Deer U13 A" }) as HTMLInputElement).checked).toBe(true);
      });
      expect((within(drawer).getByRole("checkbox", { name: "Calgary" }) as HTMLInputElement).checked).toBe(true);
      expect(within(drawer).getByRole("button", { name: "Save access" })).toBeTruthy();
    } finally {
      cleanup();
      demoUser.role = originalRole;
    }
  });

  it("shows invitation email delivery state in the people workspace", async () => {
    window.history.replaceState(null, "", "/admin#people");
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "People" });
    fireEvent.click(screen.getByRole("button", { name: "Pending Invites 1" }));

    const invitationCard = screen.getByRole("button", { name: "Open invitation for Coach New" });
    expect(within(invitationCard).getByText("Email sent")).toBeTruthy();
    fireEvent.click(invitationCard);

    const drawer = await screen.findByRole("dialog", { name: "coach@example.com" });
    expect(within(drawer).getByText("Delivery")).toBeTruthy();
    expect(within(drawer).getByText("Email sent", { selector: "span" })).toBeTruthy();
    expect(within(drawer).getByText("Expires")).toBeTruthy();
    expect(within(drawer).getByText("Head Coach")).toBeTruthy();
  });

  it("includes a profile title when creating an invitation", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: true, data: { invitationId: "invite-new" } });
    const onClose = vi.fn();

    render(
      <CreateInviteDrawer
        open
        data={demoData}
        currentUser={demoUser}
        runAction={runAction}
        onClose={onClose}
      />
    );

    const drawer = await screen.findByRole("dialog", { name: "Add Member" });
    fireEvent.change(within(drawer).getByRole("textbox", { name: "Email" }), {
      target: { value: "official@example.com" }
    });
    fireEvent.change(within(drawer).getByRole("textbox", { name: "Name Optional" }), {
      target: { value: "Jamie Official" }
    });
    fireEvent.change(within(drawer).getByRole("textbox", { name: "Title Optional" }), {
      target: { value: "Director of Officiating" }
    });
    fireEvent.click(within(drawer).getByRole("button", { name: "Create Invite" }));

    await waitFor(() => expect(runAction).toHaveBeenCalledWith("adminCreateInvitation", {
      email: "official@example.com",
      displayName: "Jamie Official",
      title: "Director of Officiating",
      role: "staff",
      hubIds: [],
      teamIds: []
    }));
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("lets an authorized administrator update a member profile title", async () => {
    const runAction = vi.fn().mockResolvedValue({ ok: true, data: {} });
    const selectedUser = {
      ...demoData.users.find((user) => user.id === "admin-1")!,
      title: "League administrator"
    };

    render(
      <UserAccessEditor
        data={demoData}
        currentUser={demoUser}
        selectedUser={selectedUser}
        runAction={runAction}
      />
    );

    const titleInput = screen.getByRole("textbox", { name: "Title" });
    expect((titleInput as HTMLInputElement).value).toBe("League administrator");
    fireEvent.change(titleInput, { target: { value: "Operations Director" } });
    fireEvent.click(screen.getByRole("button", { name: "Save title" }));

    await waitFor(() => expect(runAction).toHaveBeenCalledWith("adminUpdateUserAccess", {
      targetUserId: "admin-1",
      profilePatch: { title: "Operations Director" }
    }));
  });

  it("shows clear role choices and updates the selected access guidance", async () => {
    window.history.replaceState(null, "", "/admin#people");
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "People" });
    fireEvent.click(screen.getByRole("button", { name: "Add Member" }));

    const drawer = await screen.findByRole("dialog", { name: "Add Member" });
    const adminRole = within(drawer).getByRole("radio", { name: "Admin: Full organization access" });
    const managerRole = within(drawer).getByRole("radio", { name: "Manager: Assigned hubs and teams" });
    const staffRole = within(drawer).getByRole("radio", { name: "Staff: Standard team access" });

    expect((staffRole as HTMLInputElement).checked).toBe(true);
    expect((adminRole as HTMLInputElement).checked).toBe(false);
    expect((managerRole as HTMLInputElement).checked).toBe(false);
    expect(within(drawer).getByText(/View shared content, rosters, and policies/)).toBeTruthy();
    expect(within(drawer).getByText(/Choose the hubs and teams this staff member/)).toBeTruthy();

    fireEvent.click(adminRole);

    expect((adminRole as HTMLInputElement).checked).toBe(true);
    expect(within(drawer).getByText(/Manage existing leagues, hubs, teams, people/)).toBeTruthy();
    expect(within(drawer).getByText(/Admins automatically have access to the full organization/)).toBeTruthy();
  });

  it("renders announcement and policy workspaces as filterable, actionable card libraries", async () => {
    window.history.replaceState(null, "", "/admin#announcements");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 2, name: "Announcements for Prairie Hockey League" })).toBeTruthy();
    const announcementFilters = screen.getByRole("group", { name: "Announcements for Prairie Hockey League filters" });
    expect(within(announcementFilters).getByRole("button", { name: /All Posts/ }).getAttribute("aria-pressed")).toBe("true");
    expect(within(announcementFilters).getByRole("button", { name: /League/ })).toBeTruthy();
    expect(within(announcementFilters).getByRole("button", { name: /Hub/ })).toBeTruthy();
    expect(within(announcementFilters).getByRole("button", { name: /Team/ })).toBeTruthy();
    expect(within(announcementFilters).queryByText(/Org Wide/i)).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "New Announcement" }));
    const createAnnouncementDrawer = await screen.findByRole("dialog", { name: "New Announcement" });
    const createScopeSelect = within(createAnnouncementDrawer).getByRole("combobox", { name: "Scope" });
    expect(within(createScopeSelect).getAllByRole("option").map((option) => option.textContent)).toEqual(["League", "Hub", "Team"]);
    expect((within(createAnnouncementDrawer).getByRole("combobox", { name: "League" }) as HTMLSelectElement).value).toBe("league-winter");
    fireEvent.click(within(createAnnouncementDrawer).getByRole("button", { name: "Close drawer" }));
    const announcementButton = screen.getByRole("button", { name: "Open Schedule window posted announcement" });
    fireEvent.click(announcementButton);
    const announcementDrawer = await screen.findByRole("dialog", { name: "Schedule window posted" });
    expect(within(announcementDrawer).getByRole("button", { name: "Save changes" })).toBeTruthy();
    expect(within(within(announcementDrawer).getByRole("combobox", { name: "Scope" })).queryByRole("option", { name: /Org/i })).toBeNull();
    fireEvent.click(within(announcementDrawer).getByRole("button", { name: "Delete announcement" }));
    expect(within(announcementDrawer).getByText("Delete this announcement?")).toBeTruthy();
    expect(within(announcementDrawer).getByText("This action can’t be undone.")).toBeTruthy();
    fireEvent.click(within(announcementDrawer).getByRole("button", { name: "Cancel" }));
    fireEvent.keyDown(window, { key: "Escape" });

    fireEvent.click(screen.getAllByRole("button", { name: "Policies" })[0]);
    expect(await screen.findByRole("heading", { level: 2, name: "Policies for Prairie Hockey League" })).toBeTruthy();
    const policyFilters = screen.getByRole("group", { name: "Policies for Prairie Hockey League filters" });
    expect(within(policyFilters).getByRole("button", { name: /All Policies/ }).getAttribute("aria-pressed")).toBe("true");
    expect(within(policyFilters).getByRole("button", { name: /Waiver/ })).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: "New Policy" }));
    const createPolicyDrawer = await screen.findByRole("dialog", { name: "New Policy" });
    expect(within(createPolicyDrawer).getByText("Organization-wide")).toBeTruthy();
    expect(within(createPolicyDrawer).queryByText(/Uploading as/i)).toBeNull();
    expect(within(createPolicyDrawer).queryByText(/owner@leaguehub.local/)).toBeNull();
    const categorySelect = within(createPolicyDrawer).getByRole("combobox", { name: "Category" });
    expect(within(categorySelect).getAllByRole("option").map((option) => option.textContent)).toEqual(["Policy", "Waiver", "Protocol", "Code of Conduct", "Other"]);
    fireEvent.click(within(createPolicyDrawer).getByRole("button", { name: "Close drawer" }));
    fireEvent.click(screen.getByRole("button", { name: "Open Concussion Protocol policy" }));
    const policyDrawer = await screen.findByRole("dialog", { name: "Concussion Protocol" });
    expect(within(policyDrawer).getByTestId("drawer-scroll-region").className).toContain("overscroll-contain");
    expect(within(policyDrawer).queryByText(/Uploading as/i)).toBeNull();
    const editCategorySelect = within(policyDrawer).getByRole("combobox", { name: "Category" });
    expect((editCategorySelect as HTMLSelectElement).value).toBe("Waiver");
    expect(within(policyDrawer).getByRole("button", { name: "Save Category" }).hasAttribute("disabled")).toBe(true);
    fireEvent.change(editCategorySelect, { target: { value: "Policy" } });
    expect(within(policyDrawer).getByRole("button", { name: "Save Category" }).hasAttribute("disabled")).toBe(false);
  });

  it("shows, searches, and expands the connected league-to-hub-to-team structure with its people", async () => {
    window.history.replaceState(null, "", "/admin#structure");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 1, name: "Structure" })).toBeTruthy();
    expect(screen.getByRole("heading", { level: 2, name: "Organization structure" })).toBeTruthy();
    expect(screen.getByRole("heading", { level: 3, name: "Connected structure map" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Add league" })).toBeTruthy();
    expect(screen.getByText("Winter Hockey")).toBeTruthy();
    expect(screen.getByText("Calgary")).toBeTruthy();
    expect(screen.getByText("Calgary U11 AA")).toBeTruthy();
    expect(screen.getByRole("img", { name: "Winter Hockey logo" }).getAttribute("src")).toBe("https://cdn.example.com/winter-hockey.png");
    expect(screen.getByRole("img", { name: "Calgary logo" }).getAttribute("src")).toBe("https://cdn.example.com/calgary.png");
    expect(screen.getByRole("img", { name: "Calgary U11 AA logo" }).getAttribute("src")).toBe("https://cdn.example.com/calgary.png");
    expect(screen.getAllByText("Avery Admin").length).toBeGreaterThan(0);
    expect(screen.getAllByText("League access").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Hub access").length).toBeGreaterThan(0);

    const calgaryCollapse = screen.getByRole("button", { name: "Collapse Calgary hub" });
    fireEvent.click(calgaryCollapse);
    expect(screen.queryByRole("button", { name: "Open Calgary U11 AA team details" })).toBeNull();
    expect(screen.getByRole("button", { name: "Expand Calgary hub" }).getAttribute("aria-expanded")).toBe("false");

    fireEvent.error(screen.getByRole("img", { name: "Calgary logo" }));
    expect(screen.queryByRole("img", { name: "Calgary logo" })).toBeNull();

    fireEvent.change(screen.getByRole("textbox", { name: "Search structure or people..." }), { target: { value: "Morgan Manager" } });
    expect(screen.getByRole("button", { name: "Open Calgary U11 AA team details" })).toBeTruthy();
    expect(screen.queryByRole("button", { name: "Open Red Deer U13 A team details" })).toBeNull();
    expect((screen.getByRole("button", { name: "Matches expanded" }) as HTMLButtonElement).disabled).toBe(true);
    expect((screen.getByRole("button", { name: "Calgary hub expanded for search" }) as HTMLButtonElement).disabled).toBe(true);

    fireEvent.change(screen.getByRole("textbox", { name: "Search structure or people..." }), { target: { value: "" } });
    fireEvent.click(screen.getByRole("button", { name: "Expand Calgary hub" }));

    fireEvent.click(screen.getByRole("button", { name: "Open Calgary U11 AA team details" }));

    const drawer = await screen.findByRole("dialog", { name: "Calgary U11 AA" });
    expect(drawer.className).toContain("drawer-sheet");
    expect(within(drawer).getByText("People (2)")).toBeTruthy();
    expect(within(drawer).getByText("Avery Admin")).toBeTruthy();
    expect(within(drawer).getByText("Morgan Manager")).toBeTruthy();
    expect(within(drawer).getByRole("button", { name: "Save changes" })).toBeTruthy();
    expect(within(drawer).getByLabelText("team logo file")).toBeTruthy();
    expect(within(drawer).getByText("Replace logo")).toBeTruthy();
    fireEvent.change(within(drawer).getByLabelText("team logo file"), {
      target: { files: [new File(["logo"], "wolves.svg", { type: "image/svg+xml" })] }
    });
    expect(within(drawer).getByText("Choose a PNG, JPG, or WebP image.")).toBeTruthy();
    fireEvent.change(within(drawer).getByLabelText("team logo file"), {
      target: { files: [new File(["logo"], "wolves.png", { type: "image/png" })] }
    });
    expect(within(drawer).getByText("wolves.png")).toBeTruthy();
    fireEvent.click(within(drawer).getByRole("button", { name: "Use parent logo" }));
    expect(within(drawer).getByText("Parent logo selected")).toBeTruthy();
    fireEvent.click(within(drawer).getByRole("button", { name: "Delete team" }));
    expect(within(drawer).getByText("Delete this team?")).toBeTruthy();
  });

  it("only exposes league creation to platform owners", async () => {
    const originalRole = demoUser.role;
    demoUser.role = "superAdmin";
    window.history.replaceState(null, "", "/admin#structure");

    try {
      render(<AdminApp />);
      expect(await screen.findByRole("heading", { level: 1, name: "Structure" })).toBeTruthy();
      expect(screen.queryByRole("button", { name: "Add league" })).toBeNull();
      expect(screen.getAllByRole("button", { name: "Add hub" }).length).toBeGreaterThan(0);
      expect(screen.getAllByRole("button", { name: "Add team" }).length).toBeGreaterThan(0);
    } finally {
      cleanup();
      demoUser.role = originalRole;
    }
  });
});
