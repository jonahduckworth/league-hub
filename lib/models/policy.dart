class PolicyVersion {
  final String fileUrl;
  final int version;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String uploadedByName;
  final int fileSize;

  PolicyVersion({
    required this.fileUrl,
    required this.version,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.fileSize,
  });

  factory PolicyVersion.fromJson(Map<String, dynamic> json) => PolicyVersion(
        fileUrl: (json['url'] ?? json['fileUrl'] ?? '') as String,
        version: (json['version'] as num?)?.toInt() ?? 1,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
        uploadedBy: json['uploadedBy'] as String? ?? '',
        uploadedByName: json['uploadedByName'] as String? ?? '',
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'url': fileUrl,
        'version': version,
        'uploadedAt': uploadedAt.toIso8601String(),
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'fileSize': fileSize,
      };
}

class Policy {
  final String id;
  final String orgId;
  final String? leagueId;
  final String? hubId;
  final String? teamId;
  final String name;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final String category;
  final String uploadedBy;
  final String uploadedByName;
  final List<PolicyVersion> versions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Policy({
    required this.id,
    required this.orgId,
    this.leagueId,
    this.hubId,
    this.teamId,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.category,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.versions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        id: json['id'] as String,
        orgId: json['orgId'] as String? ?? '',
        leagueId: json['leagueId'] as String?,
        hubId: json['hubId'] as String?,
        teamId: json['teamId'] as String?,
        name: json['name'] as String,
        fileUrl: json['fileUrl'] as String,
        fileType: json['fileType'] as String,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
        category: json['category'] as String,
        uploadedBy: json['uploadedBy'] as String,
        uploadedByName: json['uploadedByName'] as String? ?? '',
        versions: (json['versions'] as List? ?? [])
            .map((v) => PolicyVersion.fromJson(v as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'orgId': orgId,
        'leagueId': leagueId,
        'hubId': hubId,
        'teamId': teamId,
        'name': name,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'fileSize': fileSize,
        'category': category,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'versions': versions.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
