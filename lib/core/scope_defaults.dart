import '../models/app_user.dart';
import '../models/league.dart';
import '../services/permission_service.dart';

List<League> manageableLeaguesForUser(AppUser? user, List<League> leagues) {
  if (user == null) return leagues;
  if (PermissionService.isAtLeast(user.role, UserRole.superAdmin)) {
    return leagues;
  }
  if (user.leagueIds.isEmpty) return leagues;
  return leagues.where((league) => user.leagueIds.contains(league.id)).toList();
}

String? singleManageableLeagueId(AppUser? user, List<League> leagues) {
  final manageableLeagues = manageableLeaguesForUser(user, leagues);
  return manageableLeagues.length == 1 ? manageableLeagues.first.id : null;
}
