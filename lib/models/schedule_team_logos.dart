class ScheduleTeamLogos {
  final Map<String, String> byTeamId;
  final Map<String, String> byClubName;

  const ScheduleTeamLogos({
    this.byTeamId = const {},
    this.byClubName = const {},
  });

  String? logoFor({String? teamId, required String teamName}) {
    final byId = teamId == null ? null : byTeamId[teamId];
    return byId ?? byClubName[normalizeScheduleClubName(teamName)];
  }
}

String normalizeScheduleClubName(String value) {
  var normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'\b(?:u\d{2}|\d{2}u)\b'), ' ')
      .replaceAll(RegExp(r'\b(?:aaa|aa|a)\b'), ' ')
      .replaceAll(RegExp(r'\bhockey academy\b'), ' ha ')
      .replaceAll(RegExp(r'\bhockey club\b'), ' hc ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized == 'island wild') normalized = 'island hc';
  return normalized;
}
