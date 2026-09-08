class AnnouncementReadReceipt {
  final String userId;
  final String orgId;
  final String announcementId;
  final DateTime readAt;

  const AnnouncementReadReceipt({
    required this.userId,
    required this.orgId,
    required this.announcementId,
    required this.readAt,
  });

  factory AnnouncementReadReceipt.fromJson(Map<String, dynamic> json) {
    return AnnouncementReadReceipt(
      userId: json['userId'] as String,
      orgId: json['orgId'] as String,
      announcementId: json['announcementId'] as String,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }
}
