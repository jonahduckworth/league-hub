class Hub {
  final String id;
  final String leagueId;
  final String orgId;
  final String name;
  final String? location;
  final DateTime createdAt;

  Hub({
    required this.id,
    required this.leagueId,
    required this.orgId,
    required this.name,
    this.location,
    required this.createdAt,
  });

  factory Hub.fromJson(Map<String, dynamic> json) => Hub(
        id: json['id'] as String,
        leagueId: json['leagueId'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        location: json['location'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'leagueId': leagueId,
        'orgId': orgId,
        'name': name,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
      };
}
