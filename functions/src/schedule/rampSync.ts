import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../helpers";
import {
  ExistingScheduleEvent,
  IncomingScheduleEvent,
  isSuspiciousScheduleDrop,
  parseRampCalendar,
  reconcileSchedule,
} from "./rampLogic";

type ScheduleIntegration = {
  provider: "ramp";
  enabled: boolean;
  baseUrl: string;
  associationId: string;
  seasonId: string;
  timezone: string;
  divisionIds: Record<string, string>;
};

type SourceTeam = {
  id: string;
  hubId: string;
  leagueId: string;
  name: string;
  sourceTeamId: string;
  sourceDivisionId: string;
};

type FeedResult = {
  team: SourceTeam;
  events: IncomingScheduleEvent[];
  error?: string;
};

export type ScheduleSyncResult = {
  status: "ok" | "warning" | "error";
  message: string;
  sourceSeasonId: string;
  teamFeedsTotal: number;
  teamFeedsSucceeded: number;
  teamFeedsFailed: number;
  eventCount: number;
  added: number;
  updated: number;
  replaced: number;
  removed: number;
  removalsSkipped: boolean;
};

const DEFAULT_BASE_URL = "https://juniorprospectshockeyleague.com";
const syncRuntime = {
  timeoutSeconds: 540,
  memory: "512MiB" as const,
};

function optionalString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
}

function integrationFromOrg(data: FirebaseFirestore.DocumentData): ScheduleIntegration | undefined {
  const raw = data.scheduleIntegration;
  if (!raw || typeof raw !== "object" || raw.provider !== "ramp" || raw.enabled !== true) {
    return undefined;
  }
  const associationId = optionalString(raw.associationId);
  const seasonId = optionalString(raw.seasonId);
  if (!associationId || !seasonId) return undefined;
  const divisionIds = raw.divisionIds && typeof raw.divisionIds === "object"
    ? Object.fromEntries(Object.entries(raw.divisionIds)
      .filter((entry): entry is [string, string] => typeof entry[1] === "string" && entry[1].trim().length > 0)
      .map(([key, value]) => [key.trim(), value.trim()]))
    : {};
  return {
    provider: "ramp",
    enabled: true,
    baseUrl: optionalString(raw.baseUrl)?.replace(/\/$/, "") ?? DEFAULT_BASE_URL,
    associationId,
    seasonId,
    timezone: optionalString(raw.timezone) ?? "America/Edmonton",
    divisionIds,
  };
}

async function loadSourceTeams(orgId: string, integration: ScheduleIntegration): Promise<SourceTeam[]> {
  const teams: SourceTeam[] = [];
  const leagues = await db.collection("organizations").doc(orgId).collection("leagues").get();
  for (const league of leagues.docs) {
    const hubs = await league.ref.collection("hubs").get();
    for (const hub of hubs.docs) {
      const snapshots = await hub.ref.collection("teams").get();
      for (const team of snapshots.docs) {
        const data = team.data();
        const sourceTeamId = optionalString(data.sourceTeamId);
        const sourceDivisionId = optionalString(data.sourceDivisionId) ??
          integration.divisionIds[optionalString(data.ageGroup) ?? ""];
        if (!sourceTeamId || !sourceDivisionId) continue;
        teams.push({
          id: team.id,
          hubId: hub.id,
          leagueId: league.id,
          name: optionalString(data.name) ?? team.id,
          sourceTeamId,
          sourceDivisionId,
        });
      }
    }
  }
  return teams;
}

function calendarUrl(integration: ScheduleIntegration, team: SourceTeam): string {
  const url = new URL(`/calendar/master-schedule/${integration.associationId}.ics`, integration.baseUrl);
  url.searchParams.set("SID", integration.seasonId);
  url.searchParams.set("CATID", "0");
  url.searchParams.set("DID", team.sourceDivisionId);
  url.searchParams.set("TID", team.sourceTeamId);
  url.searchParams.set("TZ", integration.timezone);
  return url.toString();
}

async function fetchTeamFeed(integration: ScheduleIntegration, team: SourceTeam): Promise<FeedResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    const response = await fetch(calendarUrl(integration, team), {
      signal: controller.signal,
      headers: {
        Accept: "text/calendar, text/plain;q=0.9",
        "User-Agent": "LeagueHub-ScheduleSync/1.0",
      },
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const calendar = await response.text();
    const events = parseRampCalendar(calendar, integration.timezone).map((event) => ({
      ...event,
      sourceSeasonId: integration.seasonId,
      teamIds: [team.id],
      hubIds: [team.hubId],
      leagueIds: [team.leagueId],
    }));
    return { team, events };
  } catch (error) {
    return {
      team,
      events: [],
      error: error instanceof Error ? error.message : String(error),
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchFeeds(integration: ScheduleIntegration, teams: SourceTeam[]): Promise<FeedResult[]> {
  const results: FeedResult[] = new Array(teams.length);
  let nextIndex = 0;
  const workers = Array.from({ length: Math.min(8, teams.length) }, async () => {
    while (nextIndex < teams.length) {
      const index = nextIndex++;
      results[index] = await fetchTeamFeed(integration, teams[index]);
    }
  });
  await Promise.all(workers);
  return results;
}

function aggregateEvents(results: FeedResult[]): IncomingScheduleEvent[] {
  const events = new Map<string, IncomingScheduleEvent>();
  for (const result of results) {
    if (result.error) continue;
    for (const event of result.events) {
      const existing = events.get(event.sourceUid);
      if (!existing) {
        events.set(event.sourceUid, event);
        continue;
      }
      existing.teamIds = [...new Set([...existing.teamIds, ...event.teamIds])];
      existing.hubIds = [...new Set([...existing.hubIds, ...event.hubIds])];
      existing.leagueIds = [...new Set([...existing.leagueIds, ...event.leagueIds])];
    }
  }
  return [...events.values()].sort((first, second) => first.startsAt.getTime() - second.startsAt.getTime());
}

function toDate(value: unknown): Date {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") return new Date(value);
  return new Date(0);
}

function localScheduleFields(event: IncomingScheduleEvent): {
  localDate: string;
  localStartTime: string;
  localEndTime: string;
} {
  const parts = (date: Date) => Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: event.timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );
  const start = parts(event.startsAt);
  const end = parts(event.endsAt);
  return {
    localDate: `${start.year}-${start.month}-${start.day}`,
    localStartTime: `${start.hour}:${start.minute}`,
    localEndTime: `${end.hour}:${end.minute}`,
  };
}

async function loadExistingEvents(
  orgId: string,
  currentSourceSeasonId: string,
): Promise<ExistingScheduleEvent[]> {
  const snapshot = await db.collection("organizations").doc(orgId)
    .collection("scheduleEvents").where("source", "==", "ramp").get();
  return snapshot.docs.map((document) => {
    const data = document.data();
    return {
      id: document.id,
      // Before season-aware syncing, all RAMP records belonged to the one
      // configured season. Adopt those legacy records into that current season
      // on their next successful upsert instead of duplicating them.
      sourceSeasonId: optionalString(data.sourceSeasonId) ?? currentSourceSeasonId,
      sourceUid: optionalString(data.sourceUid) ?? document.id,
      previousSourceUids: Array.isArray(data.previousSourceUids)
        ? data.previousSourceUids.filter((value): value is string => typeof value === "string")
        : [],
      startsAt: toDate(data.startsAt),
      firstTeamName: optionalString(data.firstTeamName) ?? "",
      secondTeamName: optionalString(data.secondTeamName) ?? "",
      title: optionalString(data.title) ?? "",
      location: optionalString(data.location),
      teamIds: Array.isArray(data.teamIds)
        ? data.teamIds.filter((value): value is string => typeof value === "string")
        : [],
      hubIds: Array.isArray(data.hubIds)
        ? data.hubIds.filter((value): value is string => typeof value === "string")
        : [],
      leagueIds: Array.isArray(data.leagueIds)
        ? data.leagueIds.filter((value): value is string => typeof value === "string")
        : [],
      isActive: data.isActive !== false,
      sourceMissingSince: data.sourceMissingSince ? toDate(data.sourceMissingSince) : undefined,
    };
  });
}

async function writeReconciliation(
  orgId: string,
  reconciliation: ReturnType<typeof reconcileSchedule>,
): Promise<void> {
  const events = db.collection("organizations").doc(orgId).collection("scheduleEvents");
  let batch = db.batch();
  let pending = 0;
  const commit = async () => {
    if (pending === 0) return;
    await batch.commit();
    batch = db.batch();
    pending = 0;
  };
  const addWrite = async (reference: FirebaseFirestore.DocumentReference, data: FirebaseFirestore.DocumentData) => {
    batch.set(reference, data, { merge: true });
    pending++;
    if (pending >= 450) await commit();
  };

  for (const upsert of reconciliation.upserts) {
    const event = upsert.event;
    const localFields = localScheduleFields(event);
    await addWrite(events.doc(upsert.id), {
      source: "ramp",
      sourceSeasonId: event.sourceSeasonId,
      sourceUid: event.sourceUid,
      previousSourceUids: upsert.previousSourceUids,
      sourceGameId: event.sourceGameId ?? null,
      teamIds: event.teamIds,
      hubIds: event.hubIds,
      leagueIds: event.leagueIds,
      division: event.division ?? null,
      title: event.title,
      firstTeamName: event.firstTeamName,
      secondTeamName: event.secondTeamName,
      startsAt: admin.firestore.Timestamp.fromDate(event.startsAt),
      endsAt: admin.firestore.Timestamp.fromDate(event.endsAt),
      timezone: event.timezone,
      ...localFields,
      location: event.location ?? null,
      description: event.description ?? null,
      status: event.status,
      firstScore: event.firstScore ?? null,
      secondScore: event.secondScore ?? null,
      isActive: true,
      sourceMissingSince: null,
      sourceUpdatedAt: event.sourceUpdatedAt
        ? admin.firestore.Timestamp.fromDate(event.sourceUpdatedAt)
        : null,
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(upsert.kind === "added" ? { createdAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
    });
  }
  for (const removal of reconciliation.removals) {
    await addWrite(events.doc(removal.id), {
      sourceSeasonId: removal.sourceSeasonId,
      isActive: false,
      status: "removed",
      sourceMissingSince: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await commit();
}

async function writeSyncState(orgId: string, data: FirebaseFirestore.DocumentData): Promise<void> {
  await db.collection("organizations").doc(orgId).collection("scheduleSync").doc("state")
    .set({ ...data, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
}

export async function synchronizeOrganizationSchedule(orgId: string): Promise<ScheduleSyncResult> {
  const organization = await db.collection("organizations").doc(orgId).get();
  if (!organization.exists) throw new Error("Organization was not found.");
  const integration = integrationFromOrg(organization.data() ?? {});
  if (!integration) throw new Error("RAMP schedule integration is not enabled or is incomplete.");

  await writeSyncState(orgId, {
    status: "running",
    message: "Refreshing RAMP game schedules.",
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const teams = await loadSourceTeams(orgId, integration);
    if (teams.length === 0) throw new Error("No teams have RAMP team and division IDs configured.");
    const feedResults = await fetchFeeds(integration, teams);
    const failures = feedResults.filter((result) => result.error);
    const incoming = aggregateEvents(feedResults);
    const existing = await loadExistingEvents(orgId, integration.seasonId);
    const activeExisting = existing.filter((event) =>
      event.isActive && event.sourceSeasonId === integration.seasonId,
    );
    const suspiciousDrop = isSuspiciousScheduleDrop(activeExisting.length, incoming.length);
    const removalsSkipped = failures.length > 0 || suspiciousDrop;
    const reconciliation = reconcileSchedule(existing, incoming, {
      sourceSeasonId: integration.seasonId,
      allowRemovals: !removalsSkipped,
      preserveExistingScope: removalsSkipped,
    });
    await writeReconciliation(orgId, reconciliation);

    const status = removalsSkipped ? "warning" : "ok";
    const message = failures.length > 0
      ? `${failures.length} team feed${failures.length === 1 ? "" : "s"} failed; missing games were preserved.`
      : suspiciousDrop
        ? "The feed returned an unusually small schedule; missing games were preserved."
        : "RAMP game schedules are up to date.";
    const result: ScheduleSyncResult = {
      status,
      message,
      sourceSeasonId: integration.seasonId,
      teamFeedsTotal: teams.length,
      teamFeedsSucceeded: teams.length - failures.length,
      teamFeedsFailed: failures.length,
      eventCount: incoming.length,
      ...reconciliation.counts,
      removalsSkipped,
    };
    await writeSyncState(orgId, {
      ...result,
      lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
      failedTeams: failures.slice(0, 20).map((result) => ({
        teamId: result.team.id,
        teamName: result.team.name,
        error: result.error,
      })),
    });
    return result;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await writeSyncState(orgId, { status: "error", message });
    throw error;
  }
}

export const syncRampSchedules = onSchedule({
  ...syncRuntime,
  schedule: "every 6 hours",
  retryCount: 1,
}, async () => {
  const organizations = await db.collection("organizations").get();
  const configured = organizations.docs.filter((organization) =>
    integrationFromOrg(organization.data()) != null,
  );
  const results = await Promise.allSettled(configured.map((organization) =>
    synchronizeOrganizationSchedule(organization.id),
  ));
  results.forEach((result, index) => {
    if (result.status === "rejected") {
      logger.error("RAMP schedule sync failed", {
        orgId: configured[index].id,
        error: result.reason instanceof Error ? result.reason.message : String(result.reason),
      });
    }
  });
});
