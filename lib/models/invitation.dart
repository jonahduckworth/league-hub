enum InvitationStatus { pending, accepted, expired }

class Invitation {
  final String id;
  final String orgId;
  final String email;
  final String? displayName;
  final String role; // UserRole name: 'managerAdmin' or 'staff'
  final List<String> hubIds;
  final List<String> teamIds;
  final String invitedBy;
  final String invitedByName;
  final DateTime createdAt;
  final InvitationStatus status;
  final String token;

  Invitation({
    required this.id,
    required this.orgId,
    required this.email,
    this.displayName,
    required this.role,
    required this.hubIds,
    required this.teamIds,
    required this.invitedBy,
    required this.invitedByName,
    required this.createdAt,
    required this.status,
    required this.token,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        id: json['id'] as String,
        orgId: json['orgId'] as String? ?? '',
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        role: json['role'] as String? ?? 'staff',
        hubIds: List<String>.from(json['hubIds'] as List? ?? []),
        teamIds: List<String>.from(json['teamIds'] as List? ?? []),
        invitedBy: json['invitedBy'] as String? ?? '',
        invitedByName: json['invitedByName'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: InvitationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => InvitationStatus.pending,
        ),
        token: json['token'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'orgId': orgId,
        'email': email,
        'displayName': displayName,
        'role': role,
        'hubIds': hubIds,
        'teamIds': teamIds,
        'invitedBy': invitedBy,
        'invitedByName': invitedByName,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'token': token,
      };

  String get roleLabel {
    switch (role) {
      case 'superAdmin':
        return 'Super Admin';
      case 'managerAdmin':
        return 'Manager Admin';
      case 'staff':
        return 'Staff';
      default:
        return role;
    }
  }
}
