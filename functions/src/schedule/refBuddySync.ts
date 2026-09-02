import { createHmac } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../helpers";

const REF_BUDDY_SERVICE_SECRET = defineSecret("REF_BUDDY_SERVICE_SECRET");
const REF_BUDDY_SCHEDULE_URL = "https://api.refbuddy.ca/internal/league-hub/schedule";

type TeamMapping = {
  refBuddyLeagueId: string;
  refBuddyTeamId: string;
  leagueId: string;
  hubId: string;
  teamId: string;
};

type RefBuddyIntegration = {
  enabled: true;
  teamMappings: TeamMapping[];
};

type ConfirmedCrewMember = {
  assignmentId: string;
  name: string;
  role: string;
};

type RefBuddyGame = {
  id: string;
  leagueId: string;
  homeTeamId: string;
  homeTeamName: string;
  awayTeamId: string;
  awayTeamName: string;
  startTime: string;
  venueName: string;
  gameType: string;
  confirmedCrew: ConfirmedCrewMember[];
};

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

export function integrationFromOrg(data: FirebaseFirestore.DocumentData): RefBuddyIntegration | undefined {
  const raw = data.refBuddyScheduleIntegration;
  if (!raw || raw.enabled !== true || !Array.isArray(raw.teamMappings)) return undefined;
  const teamMappings: TeamMapping[] = raw.teamMappings.flatMap((candidate: unknown): TeamMapping[] => {
    if (!candidate || typeof candidate !== "object") return [];
    const item = candidate as Record<string, unknown>;
    const mapping = {
      refBuddyLeagueId: optionalString(item.refBuddyLeagueId),
      refBuddyTeamId: optionalString(item.refBuddyTeamId),
      leagueId: optionalString(item.leagueId),
      hubId: optionalString(item.hubId),
      teamId: optionalString(item.teamId),
    };
    return Object.values(mapping).every(Boolean) ? [mapping as TeamMapping] : [];
  });
  if (teamMappings.length === 0 || teamMappings.length > 250) return undefined;
  if (new Set(teamMappings.map((item) => item.refBuddyTeamId)).size !== teamMappings.length) {
    return undefined;
  }
  return { enabled: true, teamMappings };
}

export function signedHeaders(secret: string, body: string, now = new Date()): Record<string, string> {
  const timestamp = String(Math.floor(now.getTime() / 1000));
  return {
    "Content-Type": "application/json",
    "X-RefBuddy-Timestamp": timestamp,
    "X-RefBuddy-Signature": createHmac("sha256", secret)
      .update(`${timestamp}.${body}`)
      .digest("hex"),
  };
}

async function fetchCanonicalGames(integration: RefBuddyIntegration): Promise<RefBuddyGame[]> {
  const now = new Date();
  const body = JSON.stringify({
    leagueIds: [...new Set(integration.teamMappings.map((item) => item.refBuddyLeagueId))],
    teamIds: integration.teamMappings.map((item) => item.refBuddyTeamId),
    from: new Date(now.getTime() - 180 * 86400000).toISOString(),
    to: new Date(now.getTime() + 399 * 86400000).toISOString(),
  });
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(REF_BUDDY_SCHEDULE_URL, {
      method: "POST",
      headers: signedHeaders(REF_BUDDY_SERVICE_SECRET.value(), body),
      body,
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Ref Buddy schedule returned HTTP ${response.status}`);
    const payload = await response.json() as { games?: RefBuddyGame[] };
    return Array.isArray(payload.games) ? payload.games : [];
  } finally {
    clearTimeout(timeout);
  }
}

function localFields(start: Date): { localDate: string; localStartTime: string } {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Edmonton",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(start).filter((part) => part.type !== "literal")
    .map((part) => [part.type, part.value]));
  return {
    localDate: `${parts.year}-${parts.month}-${parts.day}`,
    localStartTime: `${parts.hour}:${parts.minute}`,
  };
}

export async function synchronizeRefBuddySchedule(orgId: string): Promise<{ games: number; crews: number }> {
  const organization = await db.collection("organizations").doc(orgId).get();
  const integration = integrationFromOrg(organization.data() ?? {});
  if (!integration) throw new Error("Ref Buddy schedule integration is not enabled or is incomplete.");
  const games = await fetchCanonicalGames(integration);
  const mapping = new Map(integration.teamMappings.map((item) => [item.refBuddyTeamId, item]));
  let batch = db.batch();
  let pending = 0;
  let crewCount = 0;
  const commit = async () => {
    if (pending === 0) return;
    await batch.commit();
    batch = db.batch();
    pending = 0;
  };
  for (const game of games) {
    const first = mapping.get(game.homeTeamId);
    const second = mapping.get(game.awayTeamId);
    const scoped = [first, second].filter((item): item is TeamMapping => item != null);
    if (scoped.length === 0) continue;
    const start = new Date(game.startTime);
    if (Number.isNaN(start.getTime())) continue;
    const eventId = `refbuddy-${game.id}`;
    const teamIds = [...new Set(scoped.map((item) => item.teamId))];
    const hubIds = [...new Set(scoped.map((item) => item.hubId))];
    const leagueIds = [...new Set(scoped.map((item) => item.leagueId))];
    const eventRef = organization.ref.collection("scheduleEvents").doc(eventId);
    batch.set(eventRef, {
      orgId,
      source: "ref_buddy",
      sourceUid: game.id,
      sourceGameId: game.id,
      firstTeamId: first?.teamId ?? null,
      secondTeamId: second?.teamId ?? null,
      teamIds,
      hubIds,
      leagueIds,
      title: `${game.homeTeamName} vs ${game.awayTeamName}`,
      firstTeamName: game.homeTeamName,
      secondTeamName: game.awayTeamName,
      startsAt: admin.firestore.Timestamp.fromDate(start),
      endsAt: admin.firestore.Timestamp.fromDate(new Date(start.getTime() + 2 * 3600000)),
      timezone: "America/Edmonton",
      ...localFields(start),
      location: game.venueName,
      division: game.gameType,
      status: "scheduled",
      isActive: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    pending++;
    const crewRef = organization.ref.collection("scheduleCrews").doc(eventId);
    batch.set(crewRef, {
      orgId,
      eventId,
      teamIds,
      hubIds,
      leagueIds,
      members: game.confirmedCrew.map((member) => ({ name: member.name, role: member.role })),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    pending++;
    crewCount += game.confirmedCrew.length;
    if (pending >= 440) await commit();
  }
  await commit();
  await organization.ref.collection("scheduleSync").doc("refBuddy").set({
    status: "ok",
    message: `Ref Buddy supplied ${games.length} canonical games.`,
    eventCount: games.length,
    confirmedCrewCount: crewCount,
    lastSuccessAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return { games: games.length, crews: crewCount };
}

export const syncRefBuddySchedules = onSchedule({
  schedule: "every 15 minutes",
  timeoutSeconds: 300,
  memory: "256MiB",
  retryCount: 1,
  secrets: [REF_BUDDY_SERVICE_SECRET],
}, async () => {
  const organizations = await db.collection("organizations").get();
  const configured = organizations.docs.filter((item) => integrationFromOrg(item.data()));
  const results = await Promise.allSettled(configured.map((item) => synchronizeRefBuddySchedule(item.id)));
  results.forEach((result, index) => {
    if (result.status === "rejected") {
      logger.error("Ref Buddy schedule sync failed", {
        orgId: configured[index].id,
        error: result.reason instanceof Error ? result.reason.message : String(result.reason),
      });
    }
  });
});
