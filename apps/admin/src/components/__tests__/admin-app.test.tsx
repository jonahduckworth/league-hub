import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const adminDataMocks = vi.hoisted(() => ({
  reloadStructure: vi.fn(),
  setSelectedOrgId: vi.fn(),
  useAdminData: vi.fn()
}));

vi.mock("@/lib/firebase", () => ({
  auth: null,
  db: null,
  demoMode: true,
  firebaseProjectId: "league-hub-test",
  hasFirebaseConfig: () => true,
  storage: null
}));

vi.mock("@/lib/firestore", () => ({
  useAdminData: adminDataMocks.useAdminData
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
  deleteObject: vi.fn(),
  getDownloadURL: vi.fn(),
  ref: vi.fn(),
  uploadBytes: vi.fn()
}));

import { AdminApp } from "../admin-app";
import { demoData } from "@/lib/demo-data";

const secondOrganization = {
  ...demoData.orgs[0],
  id: "org-east",
  name: "Eastern Soccer Association"
};

describe("AdminApp operations shell", () => {
  beforeEach(() => {
    window.history.replaceState(null, "", "/admin");
    adminDataMocks.reloadStructure.mockReset().mockResolvedValue(undefined);
    adminDataMocks.setSelectedOrgId.mockReset();
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

    for (const navigation of sectionNavigations) {
      for (const section of ["Overview", "People", "Structure", "Announcements", "Policies"]) {
        expect(within(navigation).getByRole("button", { name: section })).toBeTruthy();
      }
      expect(within(navigation).getByRole("button", { name: "Overview" }).getAttribute("aria-current")).toBe("page");
      expect(within(navigation).getByRole("button", { name: "People" }).getAttribute("aria-current")).toBeNull();
    }
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
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "People" });
    expect(screen.getByRole("heading", { level: 2, name: "People at Prairie Hockey League" })).toBeTruthy();
    const memberButton = screen.getByRole("button", { name: "Open Avery Admin member details" });
    memberButton.focus();
    fireEvent.click(memberButton);

    const drawer = await screen.findByRole("dialog", { name: "Avery Admin" });
    expect(drawer.getAttribute("aria-modal")).toBe("true");
    expect(within(drawer).getByRole("heading", { name: "Avery Admin" })).toBeTruthy();
    const closeButton = within(drawer).getByRole("button", { name: "Close drawer" });
    await waitFor(() => expect(document.activeElement).toBe(closeButton));

    fireEvent.keyDown(window, { key: "Escape" });
    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: "Avery Admin" })).toBeNull();
    });
    expect(document.activeElement).toBe(memberButton);
  });

  it("renders announcement and policy workspaces as filterable, actionable card libraries", async () => {
    window.history.replaceState(null, "", "/admin#announcements");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 2, name: "Announcements for Prairie Hockey League" })).toBeTruthy();
    const announcementFilters = screen.getByRole("tablist", { name: "Announcements for Prairie Hockey League filters" });
    expect(within(announcementFilters).getByRole("tab", { name: /All Posts/ }).getAttribute("aria-selected")).toBe("true");
    const announcementButton = screen.getByRole("button", { name: "Open Schedule window posted announcement" });
    fireEvent.click(announcementButton);
    expect(await screen.findByRole("dialog", { name: "Schedule window posted" })).toBeTruthy();
    fireEvent.keyDown(window, { key: "Escape" });

    fireEvent.click(screen.getAllByRole("button", { name: "Policies" })[0]);
    expect(await screen.findByRole("heading", { level: 2, name: "Policies for Prairie Hockey League" })).toBeTruthy();
    const policyFilters = screen.getByRole("tablist", { name: "Policies for Prairie Hockey League filters" });
    expect(within(policyFilters).getByRole("tab", { name: /All Policies/ }).getAttribute("aria-selected")).toBe("true");
    fireEvent.click(screen.getByRole("button", { name: "Open Concussion Protocol policy" }));
    expect(await screen.findByRole("dialog", { name: "Concussion Protocol" })).toBeTruthy();
  });

  it("shows, searches, and expands the connected league-to-hub-to-team structure with its people", async () => {
    window.history.replaceState(null, "", "/admin#structure");
    render(<AdminApp />);

    expect(await screen.findByRole("heading", { level: 1, name: "Structure" })).toBeTruthy();
    expect(screen.getByRole("heading", { level: 2, name: "Organization structure" })).toBeTruthy();
    expect(screen.getByRole("heading", { level: 3, name: "Connected structure map" })).toBeTruthy();
    expect(screen.getByText("Winter Hockey")).toBeTruthy();
    expect(screen.getByText("Calgary")).toBeTruthy();
    expect(screen.getByText("Calgary U11 AA")).toBeTruthy();
    expect(screen.getAllByText("Avery Admin").length).toBeGreaterThan(0);
    expect(screen.getAllByText("League access").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Hub access").length).toBeGreaterThan(0);

    const calgaryCollapse = screen.getByRole("button", { name: "Collapse Calgary hub" });
    fireEvent.click(calgaryCollapse);
    expect(screen.queryByRole("button", { name: "Open Calgary U11 AA team details" })).toBeNull();
    expect(screen.getByRole("button", { name: "Expand Calgary hub" }).getAttribute("aria-expanded")).toBe("false");

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
  });
});
