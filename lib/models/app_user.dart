enum UserRole { platformOwner, superAdmin, managerAdmin, staff }

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? title;
  final String? phone;
  final String? address;
  final String? avatarUrl;
  final UserRole role;
  final String? orgId;
  final List<String> hubIds;
  final List<String> leagueIds;
  final List<String> teamIds;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.title,
    this.phone,
    this.address,
    this.avatarUrl,
    required this.role,
    this.orgId,
    required this.hubIds,
    this.leagueIds = const [],
    required this.teamIds,
    required this.createdAt,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        title: _optionalString(json['title']),
        phone: _optionalString(json['phone']),
        address: _optionalString(json['address']),
        avatarUrl: json['avatarUrl'] as String?,
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.staff,
        ),
        orgId: json['orgId'] as String?,
        hubIds: List<String>.from(json['hubIds'] as List? ?? []),
        leagueIds: List<String>.from(json['leagueIds'] as List? ?? []),
        teamIds: List<String>.from(json['teamIds'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'orgId': orgId,
      'hubIds': hubIds,
      'leagueIds': leagueIds,
      'teamIds': teamIds,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };

    final normalizedTitle = _optionalString(title);
    final normalizedPhone = _optionalString(phone);
    final normalizedAddress = _optionalString(address);
    if (normalizedTitle != null) data['title'] = normalizedTitle;
    if (normalizedPhone != null) data['phone'] = normalizedPhone;
    if (normalizedAddress != null) data['address'] = normalizedAddress;
    return data;
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String get roleLabel {
    switch (role) {
      case UserRole.platformOwner:
        return 'Platform Owner';
      case UserRole.superAdmin:
        return 'Admin';
      case UserRole.managerAdmin:
        return 'Manager';
      case UserRole.staff:
        return 'Staff';
    }
  }
}
