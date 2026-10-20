class InfoCentreItem {
  final String id, title, leagueId, status, audience;
  final String? hubId,
      teamId,
      sectionId,
      kind,
      url,
      notes,
      inviteCode,
      policyId;
  final bool hasPassword, canReveal;
  InfoCentreItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String,
        leagueId = json['leagueId'] as String,
        hubId = json['hubId'] as String?,
        teamId = json['teamId'] as String?,
        sectionId = json['sectionId'] as String?,
        kind = json['kind'] as String?,
        url = json['url'] as String?,
        notes = json['notes'] as String?,
        inviteCode = json['inviteCode'] as String?,
        policyId = json['policyId'] as String?,
        status = json['status'] as String,
        audience = json['audience'] as String,
        hasPassword = json['hasPassword'] == true,
        canReveal = json['canReveal'] == true;
}

class InfoCentreData {
  final List<InfoCentreItem> sections, entries;
  final List<Map<String, dynamic>> leagues, hubs, teams;
  const InfoCentreData(
      {this.sections = const [],
      this.entries = const [],
      this.leagues = const [],
      this.hubs = const [],
      this.teams = const []});
  factory InfoCentreData.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objects(dynamic values) =>
        (values as List? ?? [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
    final structure =
        Map<String, dynamic>.from(json['structure'] as Map? ?? {});
    return InfoCentreData(
      sections: objects(json['sections']).map(InfoCentreItem.fromJson).toList(),
      entries: objects(json['entries']).map(InfoCentreItem.fromJson).toList(),
      leagues: objects(structure['leagues']),
      hubs: objects(structure['hubs']),
      teams: objects(structure['teams']),
    );
  }
  String scopeLabel(InfoCentreItem item) {
    for (final group in [teams, hubs, leagues]) {
      final id = identical(group, teams)
          ? item.teamId
          : identical(group, hubs)
              ? item.hubId
              : item.leagueId;
      for (final value in group) {
        if (value['id'] == id) return value['name'] as String;
      }
    }
    return 'Resource';
  }

  bool visibleInHub(InfoCentreItem item, String? hubId) {
    if (hubId == null) return true;
    final hub = hubs.where((hub) => hub['id'] == hubId).firstOrNull;
    return hub != null &&
        item.leagueId == hub['leagueId'] &&
        (item.hubId == null || item.hubId == hubId);
  }
}
