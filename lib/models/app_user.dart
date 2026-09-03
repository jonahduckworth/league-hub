enum UserRole { platformOwner, superAdmin, managerAdmin, staff }

enum AnnouncementDelivery { both, push, email }

extension AnnouncementDeliveryDetails on AnnouncementDelivery {
  bool get sendsPush => this != AnnouncementDelivery.email;
  bool get sendsEmail => this != AnnouncementDelivery.push;

  String get label {
    switch (this) {
      case AnnouncementDelivery.both:
        return 'Email and push';
      case AnnouncementDelivery.push:
        return 'Push only';
      case AnnouncementDelivery.email:
        return 'Email only';
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? title;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final String? orgId;
  final List<String> hubIds;
  final List<String> leagueIds;
  final List<String> teamIds;
  final DateTime createdAt;
  final bool isActive;
  final List<String> blockedUserIds;
  final bool hasAcceptedCommunityGuidelines;
  final AnnouncementDelivery announcementDelivery;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.title,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.orgId,
    required this.hubIds,
    this.leagueIds = const [],
    required this.teamIds,
    required this.createdAt,
    required this.isActive,
    this.blockedUserIds = const [],
    this.hasAcceptedCommunityGuidelines = false,
    this.announcementDelivery = AnnouncementDelivery.both,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    title: _optionalString(json['title']),
    phone: _optionalString(json['phone']),
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
    blockedUserIds: (json['blockedUserIds'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    hasAcceptedCommunityGuidelines:
        json['hasAcceptedCommunityGuidelines'] as bool? ?? false,
    announcementDelivery: AnnouncementDelivery.values.firstWhere(
      (delivery) => delivery.name == json['announcementDelivery'],
      orElse: () => AnnouncementDelivery.both,
    ),
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
      'blockedUserIds': blockedUserIds,
      'hasAcceptedCommunityGuidelines': hasAcceptedCommunityGuidelines,
      'announcementDelivery': announcementDelivery.name,
    };

    final normalizedTitle = _optionalString(title);
    final normalizedPhone = _optionalString(phone);
    if (normalizedTitle != null) data['title'] = normalizedTitle;
    if (normalizedPhone != null) data['phone'] = normalizedPhone;
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
