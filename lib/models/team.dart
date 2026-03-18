class Team {
  final String id;
  final String hubId;
  final String leagueId;
  final String orgId;
  final String name;
  final String? ageGroup;
  final String? division;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.hubId,
    required this.leagueId,
    required this.orgId,
    required this.name,
    this.ageGroup,
    this.division,
    required this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        leagueId: json['leagueId'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        ageGroup: json['ageGroup'] as String?,
        division: json['division'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'leagueId': leagueId,
        'orgId': orgId,
        'name': name,
        'ageGroup': ageGroup,
        'division': division,
        'createdAt': createdAt.toIso8601String(),
      };
}
