enum AnnouncementScope { orgWide, league, hub }

class Announcement {
  final String id;
  final String orgId;
  final AnnouncementScope scope;
  final String? leagueId;
  final String? hubId;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final String authorRole;
  final List<String> attachments;
  final bool isPinned;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.orgId,
    required this.scope,
    this.leagueId,
    this.hubId,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.attachments,
    required this.isPinned,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        scope: AnnouncementScope.values.firstWhere(
          (e) => e.name == json['scope'],
          orElse: () => AnnouncementScope.orgWide,
        ),
        leagueId: json['leagueId'] as String?,
        hubId: json['hubId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        authorRole: json['authorRole'] as String,
        attachments: List<String>.from(json['attachments'] as List? ?? []),
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'scope': scope.name,
        'leagueId': leagueId,
        'hubId': hubId,
        'title': title,
        'body': body,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'attachments': attachments,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
      };

  String get scopeLabel {
    switch (scope) {
      case AnnouncementScope.orgWide:
        return 'Org-Wide';
      case AnnouncementScope.league:
        return 'League';
      case AnnouncementScope.hub:
        return 'Hub';
    }
  }
}
