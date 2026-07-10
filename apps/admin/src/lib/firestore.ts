"use client";

import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  type FirestoreError,
  where
} from "firebase/firestore";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type {
  AdminData,
  Announcement,
  AppUser,
  AuditLog,
  ChatRoom,
  Hub,
  Invitation,
  League,
  NotificationEvent,
  Organization,
  Policy,
  Team
} from "./types";
import { db, demoMode } from "./firebase";
import { demoData } from "./demo-data";

type LoadState = {
  data: AdminData;
  loading: boolean;
  error?: string;
  selectedOrgId?: string;
  userScopeKey?: string;
};

type RestrictedFeed = "auditLogs" | "notificationEvents";

const emptyData: AdminData = {
  orgs: [],
  users: [],
  invitations: [],
  leagues: [],
  hubs: [],
  teams: [],
  announcements: [],
  policies: [],
  chatRooms: [],
  auditLogs: [],
  notificationEvents: []
};

function clearOrganizationScopedData(data: AdminData): AdminData {
  return {
    ...emptyData,
    orgs: data.orgs
  };
}

function clearRestrictedFeedData(data: AdminData, feed: RestrictedFeed): AdminData {
  if (feed === "auditLogs") {
    return { ...data, auditLogs: [] };
  }
  return { ...data, notificationEvents: [] };
}

export function useAdminData(currentUser?: AppUser | null) {
  const userScopeKey = currentUser
    ? `${currentUser.id}:${currentUser.role}:${currentUser.orgId ?? ""}`
    : undefined;
  const currentUserOrgId = currentUser?.orgId ?? undefined;
  const currentUserRole = currentUser?.role;
  const [state, setState] = useState<LoadState>(() => ({
    data: demoMode ? demoData : emptyData,
    loading: !demoMode && Boolean(currentUser),
    selectedOrgId: currentUserOrgId,
    userScopeKey
  }));
  const structureRequestGeneration = useRef(0);
  const stateMatchesCurrentUser = state.userScopeKey === userScopeKey;
  const scopedData = stateMatchesCurrentUser
    ? state.data
    : demoMode ? demoData : emptyData;

  const selectedOrgId = !currentUser
    ? undefined
    : currentUserRole === "platformOwner"
      ? (stateMatchesCurrentUser ? state.selectedOrgId : undefined) ?? currentUserOrgId ?? scopedData.orgs[0]?.id
      : currentUserOrgId;
  const activeDataScope = useRef<{ orgId?: string; userScopeKey?: string }>({
    orgId: selectedOrgId,
    userScopeKey
  });

  useEffect(() => {
    activeDataScope.current = { orgId: selectedOrgId, userScopeKey };
  }, [selectedOrgId, userScopeKey]);

  useEffect(() => {
    if (state.userScopeKey === userScopeKey) return;
    structureRequestGeneration.current += 1;
    setState({
      data: demoMode ? demoData : emptyData,
      loading: !demoMode && Boolean(userScopeKey),
      selectedOrgId: currentUserOrgId,
      userScopeKey
    });
  }, [currentUserOrgId, state.userScopeKey, userScopeKey]);

  const setSelectedOrgId = useCallback((orgId: string) => {
    if (currentUserRole !== "platformOwner") return;
    activeDataScope.current = { orgId, userScopeKey };
    structureRequestGeneration.current += 1;
    setState((current) => ({
      ...current,
      selectedOrgId: orgId,
      loading: !demoMode,
      error: undefined,
      data: clearOrganizationScopedData(current.data)
    }));
  }, [currentUserRole, userScopeKey]);

  const isActiveDataScope = useCallback((orgId: string) => (
    activeDataScope.current.orgId === orgId &&
    activeDataScope.current.userScopeKey === userScopeKey
  ), [userScopeKey]);

  const reloadStructure = useCallback(async (orgId: string): Promise<boolean> => {
    if (!db) return false;
    const requestScope = activeDataScope.current;
    if (!requestScope.userScopeKey || requestScope.orgId !== orgId) return false;
    const requestGeneration = ++structureRequestGeneration.current;
    const requestIsCurrent = () => (
      requestGeneration === structureRequestGeneration.current &&
      activeDataScope.current.orgId === orgId &&
      activeDataScope.current.userScopeKey === requestScope.userScopeKey
    );
    try {
      const leagueSnap = await getDocs(query(collection(db, "organizations", orgId, "leagues"), orderBy("createdAt")));
      if (!requestIsCurrent()) return false;
      const leagues = leagueSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as League[];
      const hubs: Hub[] = [];
      const teams: Team[] = [];

      for (const league of leagues) {
        const hubSnap = await getDocs(query(collection(db, "organizations", orgId, "leagues", league.id, "hubs"), orderBy("createdAt")));
        if (!requestIsCurrent()) return false;
        const leagueHubs = hubSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as Hub[];
        hubs.push(...leagueHubs);
        for (const hub of leagueHubs) {
          const teamSnap = await getDocs(query(
            collection(db, "organizations", orgId, "leagues", league.id, "hubs", hub.id, "teams"),
            orderBy("createdAt")
          ));
          if (!requestIsCurrent()) return false;
          teams.push(...teamSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as Team[]);
        }
      }

      if (!requestIsCurrent()) return false;
      setState((current) => ({
        ...current,
        data: { ...current.data, leagues, hubs, teams }
      }));
      return true;
    } catch (error) {
      if (!requestIsCurrent()) return false;
      throw error;
    }
  }, []);

  useEffect(() => {
    if (demoMode) return undefined;
    if (!db || !userScopeKey) {
      return undefined;
    }

    let active = true;
    const unsubscribers: Array<() => void> = [];
    const scopeState = (current: LoadState): LoadState => current.userScopeKey === userScopeKey
      ? current
      : {
          data: emptyData,
          loading: true,
          selectedOrgId: currentUserOrgId,
          userScopeKey
        };
    setState((current) => ({ ...scopeState(current), loading: true, error: undefined }));

    if (currentUserRole === "platformOwner") {
      unsubscribers.push(onSnapshot(collection(db, "organizations"), (snap) => {
        if (!active) return;
        const orgs = snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Organization[];
        setState((current) => {
          const scoped = scopeState(current);
          const nextSelectedOrgId = scoped.selectedOrgId ?? currentUserOrgId ?? orgs[0]?.id;
          return {
            ...scoped,
            selectedOrgId: nextSelectedOrgId,
            loading: orgs.length > 0 ? scoped.loading : false,
            data: {
              ...scoped.data,
              orgs,
              selectedOrg: orgs.find((org) => org.id === nextSelectedOrgId)
            }
          };
        });
      }, (error) => {
        if (!active) return;
        setState((current) => ({ ...scopeState(current), error: error.message, loading: false }));
      }));
    } else if (currentUserOrgId) {
      unsubscribers.push(onSnapshot(doc(db, "organizations", currentUserOrgId), (snap) => {
        if (!active) return;
        const org = snap.exists() ? { id: snap.id, ...snap.data() } as Organization : undefined;
        setState((current) => {
          const scoped = scopeState(current);
          return {
            ...scoped,
            selectedOrgId: currentUserOrgId,
            loading: org ? scoped.loading : false,
            data: {
              ...scoped.data,
              orgs: org ? [org] : [],
              selectedOrg: org
            }
          };
        });
      }, (error) => {
        if (!active) return;
        setState((current) => ({ ...scopeState(current), error: error.message, loading: false }));
      }));
    }

    return () => {
      active = false;
      structureRequestGeneration.current += 1;
      unsubscribers.forEach((unsubscribe) => unsubscribe());
    };
  }, [currentUserOrgId, currentUserRole, userScopeKey]);

  useEffect(() => {
    if (demoMode) return undefined;
    if (!db || !selectedOrgId || !userScopeKey) {
      return undefined;
    }

    let active = true;
    const requiredSnapshotError = (label: string) => (error: FirestoreError) => {
      if (!active) return;
      setState((current) => ({ ...current, error: `${label}: ${error.message}`, loading: false }));
    };

    const restrictedSnapshotError = (feed: RestrictedFeed, label: string) => (error: FirestoreError) => {
      if (!active) return;
      if (error.code === "permission-denied") {
        setState((current) => ({ ...current, data: clearRestrictedFeedData(current.data, feed) }));
        return;
      }
      requiredSnapshotError(label)(error);
    };

    const unsubscribers = [
      onSnapshot(query(collection(db, "users"), where("orgId", "==", selectedOrgId)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, users: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AppUser[] }
        }));
      }, requiredSnapshotError("Users")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "invitations"), orderBy("createdAt", "desc")), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, invitations: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Invitation[] }
        }));
      }, requiredSnapshotError("Invitations")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "announcements"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, announcements: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Announcement[] }
        }));
      }, requiredSnapshotError("Announcements")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "policies"), orderBy("updatedAt", "desc"), limit(100)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, policies: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Policy[] }
        }));
      }, requiredSnapshotError("Policies")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "chatRooms"), where("isArchived", "==", false)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, chatRooms: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as ChatRoom[] }
        }));
      }, requiredSnapshotError("Chat rooms")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "auditLogs"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, auditLogs: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AuditLog[] }
        }));
      }, restrictedSnapshotError("auditLogs", "Audit logs")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "notificationEvents"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        if (!active) return;
        setState((current) => ({
          ...current,
          data: { ...current.data, notificationEvents: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as NotificationEvent[] }
        }));
      }, restrictedSnapshotError("notificationEvents", "Notification events"))
    ];

    reloadStructure(selectedOrgId)
      .then((committed) => {
        if (!active || !committed) return;
        setState((current) => ({ ...current, loading: false }));
      })
      .catch((error: Error) => {
        if (!active) return;
        setState((current) => ({ ...current, error: error.message, loading: false }));
      });

    return () => {
      active = false;
      structureRequestGeneration.current += 1;
      unsubscribers.forEach((unsubscribe) => unsubscribe());
    };
  }, [reloadStructure, selectedOrgId, userScopeKey]);

  const data = useMemo(() => {
    const source = state.userScopeKey === userScopeKey
      ? state.data
      : demoMode ? demoData : emptyData;
    const selectedOrg = source.orgs.find((org) => org.id === selectedOrgId) ?? source.selectedOrg;
    return { ...source, selectedOrg };
  }, [selectedOrgId, state.data, state.userScopeKey, userScopeKey]);

  return {
    data,
    loading: !demoMode && Boolean(currentUser) && Boolean(db)
      ? state.userScopeKey === userScopeKey ? state.loading : true
      : false,
    error: state.userScopeKey === userScopeKey ? state.error : undefined,
    selectedOrgId,
    setSelectedOrgId,
    reloadStructure,
    isActiveDataScope
  };
}
