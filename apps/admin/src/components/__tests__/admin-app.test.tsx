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

  it("provides semantic directory tables and keyboard-accessible modal drawers", async () => {
    window.history.replaceState(null, "", "/admin#people");
    render(<AdminApp />);

    await screen.findByRole("heading", { level: 1, name: "People" });
    const table = screen.getByRole("table");
    expect(within(table).getAllByRole("columnheader").map((header) => header.textContent)).toEqual([
      "Member",
      "Access",
      "Details",
      "Action"
    ]);

    const memberRow = within(table).getByRole("button", { name: "Open Avery Admin" });
    expect(memberRow.tagName).toBe("TR");
    expect(memberRow.tabIndex).toBe(0);
    fireEvent.keyDown(memberRow, { key: "Enter" });

    const drawer = await screen.findByRole("dialog", { name: "Avery Admin" });
    expect(drawer.getAttribute("aria-modal")).toBe("true");
    expect(within(drawer).getByRole("heading", { name: "Avery Admin" })).toBeTruthy();
    expect(within(drawer).getByRole("button", { name: "Close drawer" })).toBeTruthy();

    fireEvent.keyDown(window, { key: "Escape" });
    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: "Avery Admin" })).toBeNull();
    });
  });
});
