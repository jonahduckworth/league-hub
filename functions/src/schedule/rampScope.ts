import { IncomingScheduleEvent, ParsedRampEvent } from "./rampLogic";

export type ScheduleScopeTeam = {
  id: string;
  hubId: string;
  leagueId: string;
  name: string;
  ageGroup?: string;
};

function eventAgeGroup(name: string, division?: string): string | undefined {
  const match = `${division ?? ""} ${name}`.match(/\b(?:u(\d{2})|(\d{2})u)\b/i);
  const age = match?.[1] ?? match?.[2];
  return age ? `${age}U` : undefined;
}

function normalizedClubName(value: string): string {
  const normalized = value
    .toLowerCase()
    .replace(/\b(?:u\d{2}|\d{2}u)\b/g, " ")
    .replace(/\b(?:aaa|aa|a)\b/g, " ")
    .replace(/\bhockey academy\b/g, " ha ")
    .replace(/\bhockey club\b/g, " hc ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  // JPHL renamed this hub between the archived and current seasons.
  if (normalized === "island wild") return "island hc";
  return normalized;
}

function teamKey(name: string, ageGroup?: string, division?: string): string | undefined {
  const age = ageGroup?.trim().toUpperCase() || eventAgeGroup(name, division);
  const club = normalizedClubName(name);
  return age && club ? `${age}:${club}` : undefined;
}

export function scopeAssociationEvents(
  events: ParsedRampEvent[],
  sourceSeasonId: string,
  teams: ScheduleScopeTeam[],
): IncomingScheduleEvent[] {
  const configuredByKey = new Map<string, ScheduleScopeTeam>();
  const duplicateKeys = new Set<string>();
  for (const team of teams) {
    const key = teamKey(team.name, team.ageGroup);
    if (!key) continue;
    if (configuredByKey.has(key)) duplicateKeys.add(key);
    configuredByKey.set(key, team);
  }
  for (const key of duplicateKeys) configuredByKey.delete(key);

  const allLeagueIds = [...new Set(teams.map((team) => team.leagueId))];
  return events.map((event) => {
    const matched = [event.firstTeamName, event.secondTeamName]
      .map((name) => teamKey(name, undefined, event.division))
      .map((key) => key ? configuredByKey.get(key) : undefined)
      .filter((team): team is ScheduleScopeTeam => team != null);
    return {
      ...event,
      sourceSeasonId,
      teamIds: [...new Set(matched.map((team) => team.id))],
      hubIds: [...new Set(matched.map((team) => team.hubId))],
      // The association-wide archive feed belongs to the configured league even
      // when an old placeholder or retired team cannot map to a current team.
      leagueIds: [...new Set([...allLeagueIds, ...matched.map((team) => team.leagueId)])],
    };
  });
}
