import '../models/app_user.dart';
import '../models/hub.dart';
import '../models/league.dart';
import '../models/team.dart';

class VisibleContactAssignments {
  final List<League> leagues;
  final List<Hub> hubs;
  final List<Team> teams;
  final bool hasHiddenLeagues;
  final bool hasHiddenHubs;
  final bool hasHiddenTeams;

  const VisibleContactAssignments({
    required this.leagues,
    required this.hubs,
    required this.teams,
    required this.hasHiddenLeagues,
    required this.hasHiddenHubs,
    required this.hasHiddenTeams,
  });

  List<String> get hubNames => hubs.map((hub) => hub.name).toList();

  String get hubSummary {
    if (hubs.isEmpty) {
      return hasHiddenHubs ? 'No shared hub' : 'No hub assigned';
    }
    if (hubs.length == 1) return hubs.single.name;
    return '${hubs.first.name} +${hubs.length - 1} more';
  }
}

class ContactDirectoryScope {
  final List<Hub> hubs;
  final List<Team> teams;

  const ContactDirectoryScope({required this.hubs, required this.teams});
}

ContactDirectoryScope contactDirectoryScope({
  required AppUser viewer,
  required List<Hub> hubs,
  required List<Team> teams,
}) {
  final organizationWide = viewer.role == UserRole.platformOwner ||
      viewer.role == UserRole.superAdmin;
  if (organizationWide) {
    return ContactDirectoryScope(
      hubs: [...hubs]..sort(_hubByName),
      teams: [...teams]..sort(_teamByName),
    );
  }

  final viewerTeamIds = viewer.teamIds.toSet();
  final managedHubIds = viewer.hubIds.toSet();
  final viewerHubIds = <String>{
    ...managedHubIds,
    ...teams
        .where((team) => viewerTeamIds.contains(team.id))
        .map((team) => team.hubId),
  };
  final scopedHubs = hubs.where((hub) => viewerHubIds.contains(hub.id)).toList()
    ..sort(_hubByName);
  final scopedTeams = teams.where((team) {
    if (viewer.role == UserRole.managerAdmin) {
      return viewerTeamIds.contains(team.id) ||
          managedHubIds.contains(team.hubId);
    }
    return viewerTeamIds.contains(team.id);
  }).toList()
    ..sort(_teamByName);

  return ContactDirectoryScope(hubs: scopedHubs, teams: scopedTeams);
}

VisibleContactAssignments visibleContactAssignments({
  required AppUser viewer,
  required AppUser contact,
  required List<League> leagues,
  required List<Hub> hubs,
  required List<Team> teams,
}) {
  final contactTeamIds = contact.teamIds.toSet();
  final contactTeams = teams
      .where((team) => contactTeamIds.contains(team.id))
      .toList()
    ..sort(_teamByName);
  final contactHubIds = <String>{
    ...contact.hubIds,
    ...contactTeams.map((team) => team.hubId),
  };
  final contactHubs = hubs
      .where((hub) => contactHubIds.contains(hub.id))
      .toList()
    ..sort(_hubByName);

  final organizationWide = viewer.role == UserRole.platformOwner ||
      viewer.role == UserRole.superAdmin;
  late final List<Hub> visibleHubs;
  late final List<Team> visibleTeams;

  if (organizationWide) {
    visibleHubs = contactHubs;
    visibleTeams = contactTeams;
  } else {
    final viewerTeamIds = viewer.teamIds.toSet();
    final managedHubIds = viewer.hubIds.toSet();
    final viewerHubIds = <String>{
      ...managedHubIds,
      ...teams
          .where((team) => viewerTeamIds.contains(team.id))
          .map((team) => team.hubId),
    };
    visibleHubs =
        contactHubs.where((hub) => viewerHubIds.contains(hub.id)).toList();
    visibleTeams = contactTeams.where((team) {
      if (viewer.role == UserRole.managerAdmin) {
        return viewerTeamIds.contains(team.id) ||
            managedHubIds.contains(team.hubId);
      }
      return viewerTeamIds.contains(team.id);
    }).toList();
  }

  final contactLeagueIds = <String>{
    ...contact.leagueIds,
    ...contactHubs.map((hub) => hub.leagueId),
    ...contactTeams.map((team) => team.leagueId),
  };
  final visibleLeagueIds = <String>{
    ...visibleHubs.map((hub) => hub.leagueId),
    ...visibleTeams.map((team) => team.leagueId),
  };
  if (organizationWide) {
    visibleLeagueIds.addAll(contact.leagueIds);
  } else {
    visibleLeagueIds.addAll(contact.leagueIds.where(viewer.leagueIds.contains));
  }
  final visibleLeagues = leagues
      .where((league) => visibleLeagueIds.contains(league.id))
      .toList()
    ..sort(_leagueByName);

  return VisibleContactAssignments(
    leagues: visibleLeagues,
    hubs: visibleHubs,
    teams: visibleTeams,
    hasHiddenLeagues: contactLeagueIds.difference(visibleLeagueIds).isNotEmpty,
    hasHiddenHubs: contactHubs.length > visibleHubs.length,
    hasHiddenTeams: contactTeams.length > visibleTeams.length,
  );
}

int _leagueByName(League a, League b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int _hubByName(Hub a, Hub b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int _teamByName(Team a, Team b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());
