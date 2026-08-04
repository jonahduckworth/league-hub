export type ConfiguredRampTeam = {
  id: string;
  name: string;
  ageGroup?: string;
};

export type DiscoveredRampTeam = {
  seasonId: string;
  divisionId: string;
  teamId: string;
  name: string;
};

export type RampTeamAssignment = {
  configuredTeamId: string;
  sourceDivisionId: string;
  sourceTeamId: string;
};

export type RampDiscoveryResult = {
  status: "matched" | "rejected";
  message: string;
  discoveredSeasonId?: string;
  matchedTeams: number;
  expectedTeams: number;
  discoveredTeams: number;
  assignments: RampTeamAssignment[];
  divisionIds: Record<string, string>;
};

function decodeHtml(value: string): string {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_match, hex: string) =>
      String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_match, decimal: string) =>
      String.fromCodePoint(Number.parseInt(decimal, 10)))
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&apos;|&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function textContent(value: string): string {
  return decodeHtml(value.replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();
}

function normalizeTeamName(value: string): string {
  return decodeHtml(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function ageGroupFor(team: ConfiguredRampTeam): string | undefined {
  const configured = team.ageGroup?.trim();
  if (configured) return configured;
  return team.name.match(/^\s*(\d{2}U)\b/i)?.[1].toUpperCase();
}

export function parseRampDirectory(html: string): DiscoveredRampTeam[] {
  const routePattern = /<a\b[^>]*\bhref\s*=\s*["']\/team\/(\d+)\/0\/(\d+)\/(\d+)\/masterschedule(?:[?#][^"']*)?["'][^>]*>([\s\S]*?)<\/a>/gi;
  const teams = new Map<string, DiscoveredRampTeam>();
  for (const match of html.matchAll(routePattern)) {
    const [, seasonId, divisionId, teamId, body] = match;
    const paragraph = body.match(/<p\b[^>]*>([\s\S]*?)<\/p>/i)?.[1];
    const alt = body.match(/\balt\s*=\s*["']([^"']+)["']/i)?.[1];
    const name = textContent(paragraph ?? alt ?? "");
    if (!name) continue;
    const key = `${seasonId}:${divisionId}:${teamId}`;
    teams.set(key, { seasonId, divisionId, teamId, name });
  }
  return [...teams.values()];
}

export function matchRampDirectory(
  discovered: DiscoveredRampTeam[],
  configured: ConfiguredRampTeam[],
): RampDiscoveryResult {
  const rejected = (
    message: string,
    candidate?: DiscoveredRampTeam[],
    matchedTeams = 0,
  ): RampDiscoveryResult => ({
    status: "rejected",
    message,
    discoveredSeasonId: candidate?.[0]?.seasonId,
    matchedTeams,
    expectedTeams: configured.length,
    discoveredTeams: candidate?.length ?? 0,
    assignments: [],
    divisionIds: {},
  });

  if (configured.length === 0) return rejected("No League Hub teams are configured for discovery.");
  if (discovered.length === 0) return rejected("The JPHL site did not expose any team schedule routes.");

  const configuredByName = new Map<string, ConfiguredRampTeam>();
  for (const team of configured) {
    const normalized = normalizeTeamName(team.name);
    if (!normalized || configuredByName.has(normalized)) {
      return rejected(`League Hub has duplicate or invalid team names near ${team.name}.`);
    }
    configuredByName.set(normalized, team);
  }

  const bySeason = new Map<string, DiscoveredRampTeam[]>();
  for (const team of discovered) {
    const group = bySeason.get(team.seasonId) ?? [];
    group.push(team);
    bySeason.set(team.seasonId, group);
  }

  const candidates = [...bySeason.values()].map((teams) => {
    const discoveredByName = new Map<string, DiscoveredRampTeam>();
    let duplicateName = false;
    for (const team of teams) {
      const normalized = normalizeTeamName(team.name);
      if (!normalized || discoveredByName.has(normalized)) duplicateName = true;
      discoveredByName.set(normalized, team);
    }
    const matches = [...configuredByName.entries()]
      .map(([name, configuredTeam]) => ({
        configuredTeam,
        discoveredTeam: discoveredByName.get(name),
      }))
      .filter((match): match is {
        configuredTeam: ConfiguredRampTeam;
        discoveredTeam: DiscoveredRampTeam;
      } => match.discoveredTeam != null);
    const unexpected = [...discoveredByName.keys()].filter((name) => !configuredByName.has(name));
    return {
      teams,
      matches,
      duplicateName,
      unexpected,
      complete: !duplicateName && matches.length === configured.length && unexpected.length === 0,
    };
  }).sort((first, second) => second.matches.length - first.matches.length);

  const complete = candidates.filter((candidate) => candidate.complete);
  if (complete.length !== 1) {
    const best = candidates[0];
    return rejected(
      complete.length > 1
        ? "The JPHL site exposed multiple complete seasons; automatic selection was skipped."
        : `The JPHL directory matched ${best?.matches.length ?? 0} of ${configured.length} teams; automatic selection requires an exact structure match.`,
      best?.teams,
      best?.matches.length ?? 0,
    );
  }

  const selected = complete[0];
  const divisionIds: Record<string, string> = {};
  const assignments: RampTeamAssignment[] = [];
  for (const match of selected.matches) {
    const ageGroup = ageGroupFor(match.configuredTeam);
    if (!ageGroup) {
      return rejected(`Could not determine an age group for ${match.configuredTeam.name}.`, selected.teams, selected.matches.length);
    }
    const existingDivision = divisionIds[ageGroup];
    if (existingDivision && existingDivision !== match.discoveredTeam.divisionId) {
      return rejected(`The JPHL site exposed multiple division IDs for ${ageGroup}.`, selected.teams, selected.matches.length);
    }
    divisionIds[ageGroup] = match.discoveredTeam.divisionId;
    assignments.push({
      configuredTeamId: match.configuredTeam.id,
      sourceDivisionId: match.discoveredTeam.divisionId,
      sourceTeamId: match.discoveredTeam.teamId,
    });
  }

  const seasonId = selected.teams[0].seasonId;
  return {
    status: "matched",
    message: `Matched all ${configured.length} League Hub teams to JPHL season ${seasonId}.`,
    discoveredSeasonId: seasonId,
    matchedTeams: configured.length,
    expectedTeams: configured.length,
    discoveredTeams: selected.teams.length,
    assignments,
    divisionIds,
  };
}
