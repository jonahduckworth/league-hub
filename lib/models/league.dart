class League {
  final String id;
  final String orgId;
  final String name;
  final String abbreviation;
  final String? description;
  final String? logoUrl;
  final String? iconName;
  final DateTime createdAt;

  League({
    required this.id,
    required this.orgId,
    required this.name,
    required this.abbreviation,
    this.description,
    this.logoUrl,
    this.iconName,
    required this.createdAt,
  });

  factory League.fromJson(Map<String, dynamic> json) => League(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        abbreviation: json['abbreviation'] as String,
        description: json['description'] as String?,
        logoUrl: json['logoUrl'] as String?,
        iconName: json['iconName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'name': name,
        'abbreviation': abbreviation,
        'description': description,
        'logoUrl': logoUrl,
        'iconName': iconName,
        'createdAt': createdAt.toIso8601String(),
      };
}
