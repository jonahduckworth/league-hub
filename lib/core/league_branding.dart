import '../models/league.dart';

League? resolveHeaderLeague(List<League> leagues, String? selectedLeagueId) {
  if (leagues.isEmpty) return null;
  if (selectedLeagueId == null) return leagues.first;

  for (final league in leagues) {
    if (league.id == selectedLeagueId) return league;
  }

  return leagues.first;
}
