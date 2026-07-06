"use client";

import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
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
      setState((current) => ({ ...current, loading: false }));
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
      setState((current) => ({ ...current, loading: false }));
      return undefined;
    }

    const unsubscribers = [
      onSnapshot(query(collection(db, "users"), where("orgId", "==", selectedOrgId)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, users: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AppUser[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "invitations"), orderBy("createdAt", "desc")), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, invitations: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Invitation[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "announcements"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, announcements: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Announcement[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "policies"), orderBy("updatedAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, policies: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as Policy[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "chatRooms"), where("isArchived", "==", false)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, chatRooms: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as ChatRoom[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "auditLogs"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, auditLogs: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as AuditLog[] }
        }));
      }),
      onSnapshot(query(collection(db, "organizations", selectedOrgId, "notificationEvents"), orderBy("createdAt", "desc"), limit(100)), (snap) => {
        setState((current) => ({
          ...current,
          data: { ...current.data, notificationEvents: snap.docs.map((item) => ({ id: item.id, ...item.data() })) as NotificationEvent[] }
        }));
      })
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
    loading: state.loading,
    error: state.error,
    selectedOrgId,
    setSelectedOrgId,
    reloadStructure
  };
}
