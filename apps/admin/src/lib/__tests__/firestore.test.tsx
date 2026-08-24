import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { AppUser, UserRole } from "../types";

const firestoreMocks = vi.hoisted(() => ({
  addDoc: vi.fn(),
  collection: vi.fn(),
  db: { id: "test-firestore" },
  doc: vi.fn(),
  getDocs: vi.fn(),
  limit: vi.fn(),
  limitToLast: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  serverTimestamp: vi.fn(),
  where: vi.fn()
}));

vi.mock("@/lib/firebase", () => ({
  db: firestoreMocks.db,
  demoMode: false
}));

vi.mock("firebase/firestore", () => ({
  addDoc: firestoreMocks.addDoc,
  collection: firestoreMocks.collection,
  doc: firestoreMocks.doc,
  getDocs: firestoreMocks.getDocs,
  limit: firestoreMocks.limit,
  limitToLast: firestoreMocks.limitToLast,
  onSnapshot: firestoreMocks.onSnapshot,
  orderBy: firestoreMocks.orderBy,
  query: firestoreMocks.query,
  serverTimestamp: firestoreMocks.serverTimestamp,
  where: firestoreMocks.where
}));

import { sendChatRoomMessage, useAdminData, useChatRoomMessages } from "../firestore";

type TestConstraint = {
  field?: string;
  kind: "limit" | "orderBy" | "where";
  value?: unknown;
};

type TestReference = {
  constraints?: TestConstraint[];
  kind: "collection" | "doc" | "query";
  path: string;
};

type TestRecord = {
  data: object;
  id: string;
};

type TestSnapshot = ReturnType<typeof querySnapshot>;

type Subscription = {
  active: boolean;
  error?: (error: Error) => void;
  next: (snapshot: unknown) => void;
  reference: TestReference;
};

const subscriptions: Subscription[] = [];

function querySnapshot(records: TestRecord[]) {
  return {
    docs: records.map((record) => ({
      data: () => record.data,
      id: record.id
    }))
  };
}

function documentSnapshot(record: TestRecord) {
  return {
    data: () => record.data,
    exists: () => true,
    id: record.id
  };
}

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, reject, resolve };
}

function appUser(id: string, role: UserRole, orgId?: string): AppUser {
  return {
    displayName: `${id} display name`,
    email: `${id}@example.com`,
    hubIds: [],
    id,
    isActive: true,
    leagueIds: [],
    orgId,
    role,
    teamIds: []
  };
}

function record(id: string, data: object): TestRecord {
  return { data, id };
}

function subscriptionFor(path: string, orgId?: string): Subscription {
  const subscription = [...subscriptions].reverse().find((candidate) => {
    if (!candidate.active || candidate.reference.path !== path) return false;
    if (!orgId) return true;
    return candidate.reference.constraints?.some((constraint) => (
      constraint.kind === "where" && constraint.field === "orgId" && constraint.value === orgId
    ));
  });
  if (!subscription) {
    throw new Error(`No active subscription found for ${path}${orgId ? ` (${orgId})` : ""}.`);
  }
  return subscription;
}

describe("useAdminData scope isolation", () => {
  beforeEach(() => {
    subscriptions.length = 0;
    for (const mock of Object.values(firestoreMocks)) {
      if (typeof mock === "function" && "mockReset" in mock) {
        mock.mockReset();
      }
    }

    firestoreMocks.collection.mockImplementation((_database: unknown, ...segments: string[]): TestReference => ({
      kind: "collection",
      path: segments.join("/")
    }));
    firestoreMocks.doc.mockImplementation((_database: unknown, ...segments: string[]): TestReference => ({
      kind: "doc",
      path: segments.join("/")
    }));
    firestoreMocks.limit.mockImplementation((value: number): TestConstraint => ({ kind: "limit", value }));
    firestoreMocks.limitToLast.mockImplementation((value: number): TestConstraint => ({ kind: "limit", value }));
    firestoreMocks.orderBy.mockImplementation((field: string): TestConstraint => ({ field, kind: "orderBy" }));
    firestoreMocks.where.mockImplementation((field: string, _operator: string, value: unknown): TestConstraint => ({
      field,
      kind: "where",
      value
    }));
    firestoreMocks.query.mockImplementation((reference: TestReference, ...constraints: TestConstraint[]): TestReference => ({
      ...reference,
      constraints: [...(reference.constraints ?? []), ...constraints],
      kind: "query"
    }));
    firestoreMocks.onSnapshot.mockImplementation((
      reference: TestReference,
      next: (snapshot: unknown) => void,
      error?: (caught: Error) => void
    ) => {
      const subscription: Subscription = { active: true, error, next, reference };
      subscriptions.push(subscription);
      return () => {
        subscription.active = false;
      };
    });
    firestoreMocks.getDocs.mockResolvedValue(querySnapshot([]));
    firestoreMocks.addDoc.mockResolvedValue({ id: "message-new" });
    firestoreMocks.serverTimestamp.mockReturnValue("server-timestamp");
  });

  afterEach(() => {
    cleanup();
  });

  it("constrains active chat rooms to the selected organization for Firestore rules", async () => {
    const admin = appUser("admin", "superAdmin", "org-a");
    renderHook(() => useAdminData(admin));

    await waitFor(() => {
      expect(subscriptionFor("organizations/org-a/chatRooms", "org-a")).toBeTruthy();
    });

    const chatRooms = subscriptionFor("organizations/org-a/chatRooms", "org-a");
    expect(chatRooms.reference.constraints).toEqual(expect.arrayContaining([
      { field: "orgId", kind: "where", value: "org-a" },
      { field: "isArchived", kind: "where", value: false }
    ]));
  });

  it("streams only the selected shared-room conversation and caps it to 100 messages", async () => {
    const { result } = renderHook(() => useChatRoomMessages("org-a", "room-a"));
    const messages = subscriptionFor("organizations/org-a/chatRooms/room-a/messages");

    act(() => {
      messages.next(querySnapshot([record("message-1", {
        chatRoomId: "room-a",
        senderId: "member-a",
        senderName: "Member A",
        text: "Hello",
        readBy: []
      })]));
    });

    await waitFor(() => expect(result.current.messages).toHaveLength(1));
    expect(result.current.messages[0]).toMatchObject({
      id: "message-1",
      deleted: false,
      text: "Hello"
    });
    expect(messages.reference.constraints).toEqual(expect.arrayContaining([
      { field: "createdAt", kind: "orderBy" },
      { kind: "limit", value: 100 }
    ]));
  });

  it("posts a trimmed message using the mobile-compatible message contract", async () => {
    await sendChatRoomMessage({
      orgId: "org-a",
      roomId: "room-a",
      senderId: "admin-a",
      senderName: "Admin A",
      text: "  Schedule updated.  "
    });

    expect(firestoreMocks.addDoc).toHaveBeenCalledWith(
      expect.objectContaining({ path: "organizations/org-a/chatRooms/room-a/messages" }),
      {
        chatRoomId: "room-a",
        senderId: "admin-a",
        senderName: "Admin A",
        text: "Schedule updated.",
        previewText: "Schedule updated.",
        createdAt: "server-timestamp",
        readBy: ["admin-a"]
      }
    );
  });

  it("does not let a deferred organization A structure load overwrite faster organization B data", async () => {
    const orgALeagues = deferred<TestSnapshot>();
    const requestedPaths: string[] = [];
    const recordsByPath = new Map<string, TestRecord[]>([
      ["organizations/org-a/leagues/league-a/hubs", [record("hub-a", {
        leagueId: "league-a",
        name: "Hub A",
        orgId: "org-a"
      })]],
      ["organizations/org-a/leagues/league-a/hubs/hub-a/teams", [record("team-a", {
        hubId: "hub-a",
        leagueId: "league-a",
        memberIds: [],
        name: "Team A",
        orgId: "org-a"
      })]],
      ["organizations/org-b/leagues", [record("league-b", {
        abbreviation: "LB",
        name: "League B",
        orgId: "org-b"
      })]],
      ["organizations/org-b/leagues/league-b/hubs", [record("hub-b", {
        leagueId: "league-b",
        name: "Hub B",
        orgId: "org-b"
      })]],
      ["organizations/org-b/leagues/league-b/hubs/hub-b/teams", [record("team-b", {
        hubId: "hub-b",
        leagueId: "league-b",
        memberIds: [],
        name: "Team B",
        orgId: "org-b"
      })]]
    ]);

    firestoreMocks.getDocs.mockImplementation((reference: TestReference) => {
      requestedPaths.push(reference.path);
      if (reference.path === "organizations/org-a/leagues") return orgALeagues.promise;
      return Promise.resolve(querySnapshot(recordsByPath.get(reference.path) ?? []));
    });

    const owner = appUser("owner", "platformOwner", "org-a");
    const { result } = renderHook(() => useAdminData(owner));

    await waitFor(() => {
      expect(requestedPaths).toContain("organizations/org-a/leagues");
    });

    act(() => {
      result.current.setSelectedOrgId("org-b");
    });

    await waitFor(() => {
      expect(result.current.selectedOrgId).toBe("org-b");
      expect(result.current.data.leagues.map((league) => league.id)).toEqual(["league-b"]);
      expect(result.current.data.hubs.map((hub) => hub.id)).toEqual(["hub-b"]);
      expect(result.current.data.teams.map((team) => team.id)).toEqual(["team-b"]);
      expect(result.current.loading).toBe(false);
    });

    await act(async () => {
      orgALeagues.resolve(querySnapshot([record("league-a", {
        abbreviation: "LA",
        name: "League A",
        orgId: "org-a"
      })]));
      await orgALeagues.promise;
    });

    expect(requestedPaths).not.toContain("organizations/org-a/leagues/league-a/hubs");
    expect(requestedPaths).not.toContain("organizations/org-a/leagues/league-a/hubs/hub-a/teams");
    expect(result.current.selectedOrgId).toBe("org-b");
    expect(result.current.data.leagues.map((league) => league.id)).toEqual(["league-b"]);
    expect(result.current.data.hubs.map((hub) => hub.id)).toEqual(["hub-b"]);
    expect(result.current.data.teams.map((team) => team.id)).toEqual(["team-b"]);
  });

  it("rejects a delayed organization A reload that starts after organization B is active", async () => {
    const requestedPaths: string[] = [];
    const recordsByPath = new Map<string, TestRecord[]>([
      ["organizations/org-a/leagues", [record("league-a", {
        abbreviation: "LA",
        name: "League A",
        orgId: "org-a"
      })]],
      ["organizations/org-a/leagues/league-a/hubs", []],
      ["organizations/org-b/leagues", [record("league-b", {
        abbreviation: "LB",
        name: "League B",
        orgId: "org-b"
      })]],
      ["organizations/org-b/leagues/league-b/hubs", []]
    ]);
    firestoreMocks.getDocs.mockImplementation((reference: TestReference) => {
      requestedPaths.push(reference.path);
      return Promise.resolve(querySnapshot(recordsByPath.get(reference.path) ?? []));
    });

    const owner = appUser("owner", "platformOwner", "org-a");
    const { result } = renderHook(() => useAdminData(owner));

    await waitFor(() => {
      expect(result.current.data.leagues.map((league) => league.id)).toEqual(["league-a"]);
    });
    act(() => {
      result.current.setSelectedOrgId("org-b");
    });
    await waitFor(() => {
      expect(result.current.selectedOrgId).toBe("org-b");
      expect(result.current.data.leagues.map((league) => league.id)).toEqual(["league-b"]);
    });

    const orgARequestsBeforeDelayedReload = requestedPaths.filter((path) => path.startsWith("organizations/org-a/")).length;
    let delayedReloadAccepted = true;
    await act(async () => {
      delayedReloadAccepted = await result.current.reloadStructure("org-a");
    });

    expect(delayedReloadAccepted).toBe(false);
    expect(requestedPaths.filter((path) => path.startsWith("organizations/org-a/")).length).toBe(orgARequestsBeforeDelayedReload);
    expect(result.current.selectedOrgId).toBe("org-b");
    expect(result.current.data.leagues.map((league) => league.id)).toEqual(["league-b"]);
  });

  it("returns an empty scope immediately when the account changes and pins non-platform users to their organization", async () => {
    const ownerA = appUser("owner-a", "platformOwner", "org-a");
    const adminB = appUser("admin-b", "superAdmin", "org-b");
    const { result, rerender } = renderHook(
      ({ currentUser }: { currentUser: AppUser | null }) => useAdminData(currentUser),
      { initialProps: { currentUser: ownerA as AppUser | null } }
    );

    await waitFor(() => {
      expect(subscriptionFor("organizations")).toBeTruthy();
      expect(subscriptionFor("users", "org-a")).toBeTruthy();
    });
    act(() => {
      subscriptionFor("organizations").next(querySnapshot([
        record("org-a", { name: "Organization A" })
      ]));
      subscriptionFor("users", "org-a").next(querySnapshot([
        record("old-user", appUser("old-user", "staff", "org-a"))
      ]));
    });
    await waitFor(() => {
      expect(result.current.data.orgs.map((org) => org.id)).toEqual(["org-a"]);
      expect(result.current.data.users.map((user) => user.id)).toEqual(["old-user"]);
    });

    act(() => {
      rerender({ currentUser: adminB });
    });

    expect(result.current.selectedOrgId).toBe("org-b");
    expect(result.current.data.selectedOrg).toBeUndefined();
    expect(result.current.data.orgs).toEqual([]);
    expect(result.current.data.users).toEqual([]);
    expect(result.current.data.leagues).toEqual([]);

    act(() => {
      result.current.setSelectedOrgId("org-a");
    });
    expect(result.current.selectedOrgId).toBe("org-b");

    await waitFor(() => {
      expect(subscriptionFor("organizations/org-b")).toBeTruthy();
      expect(subscriptionFor("users", "org-b")).toBeTruthy();
    });
    act(() => {
      subscriptionFor("organizations/org-b").next(documentSnapshot(
        record("org-b", { name: "Organization B" })
      ));
      subscriptionFor("users", "org-b").next(querySnapshot([
        record("new-user", appUser("new-user", "staff", "org-b"))
      ]));
    });

    await waitFor(() => {
      expect(result.current.data.selectedOrg?.id).toBe("org-b");
      expect(result.current.data.users.map((user) => user.id)).toEqual(["new-user"]);
    });
    expect(result.current.data.users.some((user) => user.id === "old-user")).toBe(false);
  });

  it("clears scoped data on sign-out and ignores late callbacks from the signed-out scope", async () => {
    const adminA = appUser("admin-a", "superAdmin", "org-a");
    const { result, rerender } = renderHook(
      ({ currentUser }: { currentUser: AppUser | null }) => useAdminData(currentUser),
      { initialProps: { currentUser: adminA as AppUser | null } }
    );

    await waitFor(() => {
      expect(subscriptionFor("organizations/org-a")).toBeTruthy();
      expect(subscriptionFor("users", "org-a")).toBeTruthy();
    });
    const signedInUsersSubscription = subscriptionFor("users", "org-a");
    act(() => {
      subscriptionFor("organizations/org-a").next(documentSnapshot(
        record("org-a", { name: "Organization A" })
      ));
      signedInUsersSubscription.next(querySnapshot([
        record("signed-in-user", appUser("signed-in-user", "staff", "org-a"))
      ]));
    });
    await waitFor(() => {
      expect(result.current.data.users.map((user) => user.id)).toEqual(["signed-in-user"]);
    });

    act(() => {
      rerender({ currentUser: null });
    });

    expect(result.current.selectedOrgId).toBeUndefined();
    expect(result.current.loading).toBe(false);
    expect(result.current.error).toBeUndefined();
    expect(result.current.data.selectedOrg).toBeUndefined();
    expect(result.current.data.orgs).toEqual([]);
    expect(result.current.data.users).toEqual([]);
    expect(result.current.data.leagues).toEqual([]);

    act(() => {
      signedInUsersSubscription.next(querySnapshot([
        record("late-user", appUser("late-user", "staff", "org-a"))
      ]));
    });
    expect(result.current.data.users).toEqual([]);
  });
});
