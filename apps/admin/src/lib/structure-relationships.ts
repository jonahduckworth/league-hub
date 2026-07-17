import type { AppUser, Hub, League, Team } from "./types";

export type StructureRelationshipIndex = {
  directPeopleForLeague: (leagueId: string) => AppUser[];
  directPeopleForHub: (hubId: string) => AppUser[];
  peopleForLeague: (leagueId: string) => AppUser[];
  peopleForHub: (hubId: string) => AppUser[];
  peopleForTeam: (teamId: string) => AppUser[];
};

type StructureRelationshipData = Pick<
  { users: AppUser[]; leagues: League[]; hubs: Hub[]; teams: Team[] },
  "users" | "leagues" | "hubs" | "teams"
>;

function uniquePeople(people: AppUser[]) {
  return Array.from(new Map(people.map((person) => [person.id, person])).values()).sort((left, right) =>
    left.displayName.localeCompare(right.displayName)
  );
}

/**
 * Builds a read-only view of the organization hierarchy from both sides of
 * each relationship. Keeping the two sources together means the admin UI can
 * surface people whether their access is recorded on the user, the team, or
 * both while avoiding duplicate roster entries.
 */
export function buildStructureRelationshipIndex({ users, hubs, teams }: StructureRelationshipData): StructureRelationshipIndex {
  const peopleById = new Map(users.map((person) => [person.id, person]));
  const teamsByHub = new Map<string, Team[]>();
  const hubsByLeague = new Map<string, Hub[]>();
  const directPeopleByHub = new Map<string, AppUser[]>();
  const directPeopleByLeague = new Map<string, AppUser[]>();
  const peopleByTeam = new Map<string, AppUser[]>();
  const peopleByHub = new Map<string, AppUser[]>();
  const peopleByLeague = new Map<string, AppUser[]>();

  for (const hub of hubs) {
    const leagueHubs = hubsByLeague.get(hub.leagueId) ?? [];
    leagueHubs.push(hub);
    hubsByLeague.set(hub.leagueId, leagueHubs);
  }

  for (const team of teams) {
    const hubTeams = teamsByHub.get(team.hubId) ?? [];
    hubTeams.push(team);
    teamsByHub.set(team.hubId, hubTeams);

    const membersRecordedOnTeam = team.memberIds
      .map((personId) => peopleById.get(personId))
      .filter((person): person is AppUser => Boolean(person));
    const membersRecordedOnUser = users.filter((person) => person.teamIds.includes(team.id));
    peopleByTeam.set(team.id, uniquePeople([...membersRecordedOnTeam, ...membersRecordedOnUser]));
  }

  for (const hub of hubs) {
    const peopleAssignedToHub = uniquePeople(users.filter((person) => person.hubIds.includes(hub.id)));
    const peopleOnHubTeams = (teamsByHub.get(hub.id) ?? []).flatMap((team) => peopleByTeam.get(team.id) ?? []);
    directPeopleByHub.set(hub.id, peopleAssignedToHub);
    peopleByHub.set(hub.id, uniquePeople([...peopleAssignedToHub, ...peopleOnHubTeams]));
  }

  const leagueIds = new Set([
    ...hubs.map((hub) => hub.leagueId),
    ...teams.map((team) => team.leagueId),
    ...users.flatMap((person) => person.leagueIds)
  ]);
  for (const leagueId of leagueIds) {
    const peopleAssignedToLeague = uniquePeople(users.filter((person) => person.leagueIds.includes(leagueId)));
    const peopleInLeagueHubs = (hubsByLeague.get(leagueId) ?? []).flatMap((hub) => peopleByHub.get(hub.id) ?? []);
    directPeopleByLeague.set(leagueId, peopleAssignedToLeague);
    peopleByLeague.set(leagueId, uniquePeople([...peopleAssignedToLeague, ...peopleInLeagueHubs]));
  }

  return {
    directPeopleForLeague: (leagueId) => directPeopleByLeague.get(leagueId) ?? [],
    directPeopleForHub: (hubId) => directPeopleByHub.get(hubId) ?? [],
    peopleForLeague: (leagueId) => peopleByLeague.get(leagueId) ?? [],
    peopleForHub: (hubId) => peopleByHub.get(hubId) ?? [],
    peopleForTeam: (teamId) => peopleByTeam.get(teamId) ?? []
  };
}
