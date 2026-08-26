import 'package:cloud_functions/cloud_functions.dart';

import '../models/team.dart';

const maximumMultiTeamEventRoomTeams = 50;

Map<String, dynamic> multiTeamEventRoomRequest({
  required String orgId,
  required String name,
  required String leagueId,
  required List<Team> teams,
  required String roomIconName,
}) {
  if (teams.isEmpty || teams.length > maximumMultiTeamEventRoomTeams) {
    throw ArgumentError.value(
      teams.length,
      'teams',
      'Select between 1 and $maximumMultiTeamEventRoomTeams teams.',
    );
  }
  return {
    'orgId': orgId,
    'name': name.trim(),
    'leagueId': leagueId,
    'teams': teams
        .map((team) => {'hubId': team.hubId, 'teamId': team.id})
        .toList(),
    'roomIconName': roomIconName,
  };
}

abstract class ChatRoomFunctionsClient {
  Future<String> createMultiTeamEventRoom({
    required String orgId,
    required String name,
    required String leagueId,
    required List<Team> teams,
    required String roomIconName,
  });
}

class ChatRoomFunctionsService implements ChatRoomFunctionsClient {
  final FirebaseFunctions _functions;

  ChatRoomFunctionsService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<String> createMultiTeamEventRoom({
    required String orgId,
    required String name,
    required String leagueId,
    required List<Team> teams,
    required String roomIconName,
  }) async {
    final result = await _functions
        .httpsCallable('createMultiTeamEventRoom')
        .call<Map<String, dynamic>>(multiTeamEventRoomRequest(
      orgId: orgId,
      name: name,
      leagueId: leagueId,
      teams: teams,
      roomIconName: roomIconName,
    ));
    final roomId = result.data['roomId'];
    if (roomId is! String || roomId.isEmpty) {
      throw StateError('The room was created without a valid identifier.');
    }
    return roomId;
  }
}
