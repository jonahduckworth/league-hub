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
import { useCallback, useEffect, useMemo, useState } from "react";
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

function clearRestrictedFeedData(data: AdminData, feed: RestrictedFeed): AdminData {
  if (feed === "auditLogs") {
    return { ...data, auditLogs: [] };
  }
  return { ...data, notificationEvents: [] };
}

export function useAdminData(currentUser?: AppUser | null) {
  const [state, setState] = useState<LoadState>({
    data: demoMode ? demoData : emptyData,
    loading: !demoMode
  });

  const selectedOrgId = state.selectedOrgId ?? currentUser?.orgId ?? state.data.orgs[0]?.id;

  const setSelectedOrgId = useCallback((orgId: string) => {
    setState((current) => ({ ...current, selectedOrgId: orgId }));
  }, []);

  const reloadStructure = useCallback(async (orgId: string) => {
    if (!db) return;
    const leagueSnap = await getDocs(query(collection(db, "organizations", orgId, "leagues"), orderBy("createdAt")));
    const leagues = leagueSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as League[];
    const hubs: Hub[] = [];
    const teams: Team[] = [];

    for (const league of leagues) {
      const hubSnap = await getDocs(query(collection(db, "organizations", orgId, "leagues", league.id, "hubs"), orderBy("createdAt")));
      const leagueHubs = hubSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as Hub[];
      hubs.push(...leagueHubs);
      for (const hub of leagueHubs) {
        const teamSnap = await getDocs(query(
          collection(db, "organizations", orgId, "leagues", league.id, "hubs", hub.id, "teams"),
          orderBy("createdAt")
        ));
        teams.push(...teamSnap.docs.map((item) => ({ id: item.id, ...item.data() })) as Team[]);
      }
    }

    setState((current) => ({
      ...current,
      data: { ...current.data, leagues, hubs, teams }
    }));
  }, []);

  useEffect(() => {
    if (demoMode) return undefined;
    if (!db || !currentUser) {
      return undefined;
    }

    const unsubscribers: Array<() => void> = [];
    setState((current) => ({ ...current, loading: true, error: undefined }));

    if (currentUser.role === "platformOwner") {
      unsubscribers.push(onSnapshot(collection(db, "organizations"), (snap) => {
        const orgs = snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Organization[];
        setState((current) => ({
          ...current,
          selectedOrgId: current.selectedOrgId ?? currentUser.orgId ?? orgs[0]?.id,
          loading: orgs.length > 0 ? current.loading : false,
          data: {
            ...current.data,
            orgs,
            selectedOrg: orgs.find((org) => org.id === (current.selectedOrgId ?? currentUser.orgId ?? orgs[0]?.id))
          }
        }));
      }, (error) => {
        setState((current) => ({ ...current, error: error.message, loading: false }));
      }));
    } else if (currentUser.orgId) {
      unsubscribers.push(onSnapshot(doc(db, "organizations", currentUser.orgId), (snap) => {
        const org = snap.exists() ? { id: snap.id, ...snap.data() } as Organization : undefined;
        setState((current) => ({
          ...current,
          selectedOrgId: current.selectedOrgId ?? currentUser.orgId ?? undefined,
          loading: org ? current.loading : false,
          data: {
            ...current.data,
            orgs: org ? [org] : [],
            selectedOrg: org
          }
        }));
      }, (error) => {
        setState((current) => ({ ...current, error: error.message, loading: false }));
      }));
    }

    return () => {
      unsubscribers.forEach((unsubscribe) => unsubscribe());
    };
  }, [currentUser]);

  useEffect(() => {
    if (demoMode) return undefined;
    if (!db || !selectedOrgId) {
      return undefined;
    }

    const requiredSnapshotError = (label: string) => (error: FirestoreError) => {
      setState((current) => ({ ...current, error: `${label}: ${error.message}`, loading: false }));
    };

    const restrictedSnapshotError = (feed: RestrictedFeed, label: string) => (error: FirestoreError) => {
      if (error.code === "permission-denied") {
        setState((current) => ({ ...current, data: clearRestrictedFeedData(current.data, feed) }));
        return;
      }
      requiredSnapshotError(label)(error);
    };

    const unsubscribers = [
      onSnapshot(query(collection(db, "users"), where("orgId", "==", selectedOrgId)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, users: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AppUser[] }
        }));
      }, requiredSnapshotError("Users")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "invitations"), orderBy("createdAt", "desc")), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, invitations: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Invitation[] }
        }));
      }, requiredSnapshotError("Invitations")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "announcements"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, announcements: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Announcement[] }
        }));
      }, requiredSnapshotError("Announcements")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "policies"), orderBy("updatedAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, policies: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Policy[] }
        }));
      }, requiredSnapshotError("Policies")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "chatRooms"), where("isArchived", "==", false)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, chatRooms: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as ChatRoom[] }
        }));
      }, requiredSnapshotError("Chat rooms")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "auditLogs"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, auditLogs: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AuditLog[] }
        }));
      }, restrictedSnapshotError("auditLogs", "Audit logs")),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "notificationEvents"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, notificationEvents: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as NotificationEvent[] }
        }));
      }, restrictedSnapshotError("notificationEvents", "Notification events"))
    ];

    reloadStructure(selectedOrgId)
      .then(() => setState((current) => ({ ...current, loading: false })))
      .catch((error: Error) => setState((current) => ({ ...current, error: error.message, loading: false })));

    return () => {
      unsubscribers.forEach((unsubscribe) => unsubscribe());
    };
  }, [reloadStructure, selectedOrgId]);

  const data = useMemo(() => {
    const selectedOrg = state.data.orgs.find((org) => org.id === selectedOrgId) ?? state.data.selectedOrg;
    return { ...state.data, selectedOrg };
  }, [selectedOrgId, state.data]);

  return {
    data,
    loading: !demoMode && Boolean(currentUser) && Boolean(db) ? state.loading : false,
    error: state.error,
    selectedOrgId,
    setSelectedOrgId,
    reloadStructure
  };
}
