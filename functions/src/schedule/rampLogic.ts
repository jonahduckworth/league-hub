import { createHash } from "crypto";

export type ScheduleStatus = "scheduled" | "final";

export type ParsedRampEvent = {
  sourceUid: string;
  sourceGameId?: string;
  startsAt: Date;
  endsAt: Date;
  sourceUpdatedAt?: Date;
  timezone: string;
  division?: string;
  firstTeamName: string;
  secondTeamName: string;
  title: string;
  description?: string;
  location?: string;
  status: ScheduleStatus;
  firstScore?: number;
  secondScore?: number;
};

export type IncomingScheduleEvent = ParsedRampEvent & {
  sourceSeasonId: string;
  firstTeamId?: string;
  secondTeamId?: string;
  teamIds: string[];
  hubIds: string[];
  leagueIds: string[];
};

export type ExistingScheduleEvent = {
  id: string;
  sourceSeasonId: string;
  sourceUid: string;
  previousSourceUids: string[];
  startsAt: Date;
  firstTeamName: string;
  secondTeamName: string;
  title: string;
  location?: string;
  firstTeamId?: string;
  secondTeamId?: string;
  teamIds: string[];
  hubIds: string[];
  leagueIds: string[];
  isActive: boolean;
  sourceMissingSince?: Date;
};

export type ReconciledUpsert = {
  id: string;
  event: IncomingScheduleEvent;
  previousSourceUids: string[];
  kind: "added" | "updated" | "replaced";
};

export type ReconciliationResult = {
  upserts: ReconciledUpsert[];
  removals: ExistingScheduleEvent[];
  counts: {
    added: number;
    updated: number;
    replaced: number;
    removed: number;
  };
};

export type ReconciliationOptions = {
  sourceSeasonId: string;
  allowRemovals: boolean;
  preserveExistingScope?: boolean;
  now?: Date;
};

type ContentLine = {
  name: string;
  params: Record<string, string>;
  value: string;
};

const gameUidPattern = /(?:league|tournament)game-/i;

function unfoldCalendar(value: string): string[] {
  return value
    .replace(/\r\n/g, "\n")
    .replace(/\n[ \t]/g, "")
    .split("\n");
}

function parseContentLine(line: string): ContentLine | undefined {
  const separator = line.indexOf(":");
  if (separator < 0) return undefined;
  const header = line.slice(0, separator).split(";");
  const name = header.shift()?.toUpperCase();
  if (!name) return undefined;
  const params: Record<string, string> = {};
  for (const parameter of header) {
    const equals = parameter.indexOf("=");
    if (equals > 0) {
      params[parameter.slice(0, equals).toUpperCase()] = parameter.slice(equals + 1);
    }
  }
  return { name, params, value: line.slice(separator + 1) };
}

function unescapeText(value: string): string {
  return value
    .replace(/\\[nN]/g, "\n")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
    .trim();
}

function datePartsInZone(date: Date, timezone: string): Record<string, number> {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  return Object.fromEntries(
    formatter.formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, Number(part.value)]),
  );
}

function zonedDateToUtc(parts: number[], timezone: string): Date {
  const [year, month, day, hour = 0, minute = 0, second = 0] = parts;
  const requestedAsUtc = Date.UTC(year, month - 1, day, hour, minute, second);
  let candidate = new Date(requestedAsUtc);
  for (let attempt = 0; attempt < 2; attempt++) {
    const actual = datePartsInZone(candidate, timezone);
    const actualAsUtc = Date.UTC(
      actual.year,
      actual.month - 1,
      actual.day,
      actual.hour,
      actual.minute,
      actual.second,
    );
    candidate = new Date(candidate.getTime() + requestedAsUtc - actualAsUtc);
  }
  return candidate;
}

function parseCalendarDate(value: string, timezone: string): Date {
  if (/^\d{8}T\d{6}Z$/.test(value)) {
    return new Date(Date.UTC(
      Number(value.slice(0, 4)),
      Number(value.slice(4, 6)) - 1,
      Number(value.slice(6, 8)),
      Number(value.slice(9, 11)),
      Number(value.slice(11, 13)),
      Number(value.slice(13, 15)),
    ));
  }
  const match = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?$/);
  if (!match) throw new Error(`Unsupported calendar date: ${value}`);
  return zonedDateToUtc(match.slice(1).filter(Boolean).map(Number), timezone);
}

function splitSummary(summary: string): {
  division?: string;
  firstTeamName: string;
  secondTeamName: string;
} {
  const colon = summary.indexOf(":");
  const division = colon >= 0 ? summary.slice(0, colon).trim() : undefined;
  const matchup = (colon >= 0 ? summary.slice(colon + 1) : summary).trim();
  const [first = matchup, second = ""] = matchup.split(/\s+vs\s+/i, 2);
  return {
    division,
    firstTeamName: first.trim(),
    secondTeamName: second.trim(),
  };
}

function parseScore(description?: string): {
  status: ScheduleStatus;
  firstScore?: number;
  secondScore?: number;
} {
  const match = description?.match(/\bFinal:\s*(\d+)\s*-\s*(\d+)/i);
  if (!match) return { status: "scheduled" };
  return {
    status: "final",
    firstScore: Number(match[1]),
    secondScore: Number(match[2]),
  };
}

export function parseRampCalendar(calendar: string, fallbackTimezone: string): ParsedRampEvent[] {
  if (!calendar.includes("BEGIN:VCALENDAR")) {
    throw new Error("RAMP response was not an iCalendar feed.");
  }
  const lines = unfoldCalendar(calendar);
  const events: ParsedRampEvent[] = [];
  let current: ContentLine[] | undefined;

  for (const rawLine of lines) {
    if (rawLine === "BEGIN:VEVENT") {
      current = [];
      continue;
    }
    if (rawLine === "END:VEVENT") {
      if (!current) continue;
      const byName = new Map(current.map((line) => [line.name, line]));
      const uid = byName.get("UID")?.value.trim();
      const startLine = byName.get("DTSTART");
      const endLine = byName.get("DTEND");
      const summary = unescapeText(byName.get("SUMMARY")?.value ?? "");
      if (!uid || !startLine || !endLine || !summary || !gameUidPattern.test(uid)) {
        current = undefined;
        continue;
      }
      const timezone = startLine.params.TZID ?? fallbackTimezone;
      const matchup = splitSummary(summary);
      const description = unescapeText(byName.get("DESCRIPTION")?.value ?? "") || undefined;
      const score = parseScore(description);
      const sourceGameId = uid.match(/game-(\d+)/i)?.[1];
      events.push({
        sourceUid: uid,
        sourceGameId,
        startsAt: parseCalendarDate(startLine.value, timezone),
        endsAt: parseCalendarDate(endLine.value, endLine.params.TZID ?? timezone),
        sourceUpdatedAt: byName.get("DTSTAMP")
          ? parseCalendarDate(byName.get("DTSTAMP")!.value, "UTC")
          : undefined,
        timezone,
        division: matchup.division,
        firstTeamName: matchup.firstTeamName,
        secondTeamName: matchup.secondTeamName,
        title: `${matchup.firstTeamName} vs ${matchup.secondTeamName}`,
        description,
        location: unescapeText(byName.get("LOCATION")?.value ?? "") || undefined,
        ...score,
      });
      current = undefined;
      continue;
    }
    if (current) {
      const line = parseContentLine(rawLine);
      if (line) current.push(line);
    }
  }
  return events;
}

function normalize(value?: string): string {
  return (value ?? "")
    .toLowerCase()
    .replace(/\b\d{2}u\s+(?:aaa|aa|a)\s*-\s*/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function shareValue(first: string[], second: string[]): boolean {
  const values = new Set(first);
  return second.some((value) => values.has(value));
}

// RAMP replacements caused by minor edits stay close to the original slot. A
// hard bound is safer than recycling an ID for a later game between repeat opponents.
const replacementTimeWindowMs = 72 * 60 * 60 * 1000;
const recentlyMissingWindowMs = 14 * 24 * 60 * 60 * 1000;

export function isSuspiciousScheduleDrop(
  activeExistingCount: number,
  incomingCount: number,
): boolean {
  return activeExistingCount > 0 && incomingCount < activeExistingCount * 0.65;
}

export function existingSourceSeasonId(value: unknown, persistedSeasonId: string): string {
  return typeof value === "string" && value.trim() ? value.trim() : persistedSeasonId;
}

function replacementScore(existing: ExistingScheduleEvent, incoming: IncomingScheduleEvent): number {
  const timeDifference = Math.abs(existing.startsAt.getTime() - incoming.startsAt.getTime());
  if (timeDifference > replacementTimeWindowMs) return 0;

  let score = 0;
  const exactTeams = normalize(existing.firstTeamName) === normalize(incoming.firstTeamName) &&
    normalize(existing.secondTeamName) === normalize(incoming.secondTeamName);
  const reversedTeams = normalize(existing.firstTeamName) === normalize(incoming.secondTeamName) &&
    normalize(existing.secondTeamName) === normalize(incoming.firstTeamName);
  if (exactTeams || reversedTeams) score += 7;
  if (normalize(existing.title) === normalize(incoming.title)) score += 5;
  if (shareValue(existing.teamIds, incoming.teamIds)) score += 4;
  score += 4;
  if (normalize(existing.location) && normalize(existing.location) === normalize(incoming.location)) score += 1;
  return score;
}

function withPreservedScope(
  incoming: IncomingScheduleEvent,
  existing: ExistingScheduleEvent,
  preserveExistingScope: boolean,
): IncomingScheduleEvent {
  if (!preserveExistingScope) return incoming;
  const preservedTeamId = (incomingName: string): string | undefined => {
    if (normalize(existing.firstTeamName) === normalize(incomingName)) {
      return existing.firstTeamId;
    }
    if (normalize(existing.secondTeamName) === normalize(incomingName)) {
      return existing.secondTeamId;
    }
    return undefined;
  };
  return {
    ...incoming,
    firstTeamId: incoming.firstTeamId ?? preservedTeamId(incoming.firstTeamName),
    secondTeamId: incoming.secondTeamId ?? preservedTeamId(incoming.secondTeamName),
    teamIds: [...new Set([...existing.teamIds, ...incoming.teamIds])],
    hubIds: [...new Set([...existing.hubIds, ...incoming.hubIds])],
    leagueIds: [...new Set([...existing.leagueIds, ...incoming.leagueIds])],
  };
}

function newDocumentId(sourceSeasonId: string, sourceUid: string): string {
  return `ramp_${createHash("sha256")
    .update(`${sourceSeasonId}:${sourceUid}`)
    .digest("hex")
    .slice(0, 24)}`;
}

export function reconcileSchedule(
  existing: ExistingScheduleEvent[],
  incoming: IncomingScheduleEvent[],
  options: ReconciliationOptions,
): ReconciliationResult {
  const {
    sourceSeasonId,
    allowRemovals,
    preserveExistingScope = false,
    now = new Date(),
  } = options;
  if (incoming.some((event) => event.sourceSeasonId !== sourceSeasonId)) {
    throw new Error("Schedule reconciliation received events from multiple seasons.");
  }
  // Historical seasons remain active and visible. A sync may only update or
  // remove records belonging to the season explicitly selected by the admin.
  const seasonExisting = existing.filter((event) => event.sourceSeasonId === sourceSeasonId);
  const existingByUid = new Map<string, ExistingScheduleEvent>();
  for (const event of seasonExisting) {
    existingByUid.set(event.sourceUid, event);
    for (const uid of event.previousSourceUids) existingByUid.set(uid, event);
  }

  const matchedExisting = new Set<string>();
  const unmatchedIncoming: IncomingScheduleEvent[] = [];
  const upserts: ReconciledUpsert[] = [];

  for (const event of incoming) {
    const match = existingByUid.get(event.sourceUid);
    if (!match || matchedExisting.has(match.id)) {
      unmatchedIncoming.push(event);
      continue;
    }
    matchedExisting.add(match.id);
    upserts.push({
      id: match.id,
      event: withPreservedScope(event, match, preserveExistingScope),
      previousSourceUids: match.previousSourceUids,
      kind: "updated",
    });
  }

  const missing = seasonExisting.filter((event) => {
    if (matchedExisting.has(event.id)) return false;
    if (event.isActive) return true;
    if (!event.sourceMissingSince) return false;
    const missingAge = now.getTime() - event.sourceMissingSince.getTime();
    return missingAge >= 0 && missingAge <= recentlyMissingWindowMs;
  });
  for (const event of unmatchedIncoming) {
    const ranked = missing
      .filter((candidate) => !matchedExisting.has(candidate.id))
      .map((candidate) => ({ candidate, score: replacementScore(candidate, event) }))
      .filter((match) => match.score >= 9)
      .sort((first, second) => second.score - first.score);
    const replacement = ranked[0];
    const unambiguous = replacement && (!ranked[1] || replacement.score - ranked[1].score >= 2);
    if (replacement && unambiguous) {
      matchedExisting.add(replacement.candidate.id);
      upserts.push({
        id: replacement.candidate.id,
        event: withPreservedScope(event, replacement.candidate, preserveExistingScope),
        previousSourceUids: [...new Set([
          ...replacement.candidate.previousSourceUids,
          replacement.candidate.sourceUid,
        ])],
        kind: "replaced",
      });
    } else {
      upserts.push({
        id: newDocumentId(event.sourceSeasonId, event.sourceUid),
        event,
        previousSourceUids: [],
        kind: "added",
      });
    }
  }

  const removals = allowRemovals
    ? seasonExisting.filter((event) => event.isActive && !matchedExisting.has(event.id))
    : [];
  return {
    upserts,
    removals,
    counts: {
      added: upserts.filter((event) => event.kind === "added").length,
      updated: upserts.filter((event) => event.kind === "updated").length,
      replaced: upserts.filter((event) => event.kind === "replaced").length,
      removed: removals.length,
    },
  };
}
