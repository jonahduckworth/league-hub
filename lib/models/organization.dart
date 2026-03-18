class Organization {
  final String id;
  final String name;
  final String? logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final DateTime createdAt;
  final String ownerId;

  Organization({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.createdAt,
    required this.ownerId,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
        logoUrl: json['logoUrl'] as String?,
        primaryColor: json['primaryColor'] as String? ?? '#1A3A5C',
        secondaryColor: json['secondaryColor'] as String? ?? '#2E75B6',
        accentColor: json['accentColor'] as String? ?? '#4DA3FF',
        createdAt: DateTime.parse(json['createdAt'] as String),
        ownerId: json['ownerId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'createdAt': createdAt.toIso8601String(),
        'ownerId': ownerId,
      };
}
