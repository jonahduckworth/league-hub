class DocumentVersion {
  final String fileUrl;
  final int version;
  final DateTime uploadedAt;
  final String uploadedBy;

  DocumentVersion({
    required this.fileUrl,
    required this.version,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory DocumentVersion.fromJson(Map<String, dynamic> json) => DocumentVersion(
        fileUrl: json['fileUrl'] as String,
        version: json['version'] as int,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
        uploadedBy: json['uploadedBy'] as String,
      );

  Map<String, dynamic> toJson() => {
        'fileUrl': fileUrl,
        'version': version,
        'uploadedAt': uploadedAt.toIso8601String(),
        'uploadedBy': uploadedBy,
      };
}

class Document {
  final String id;
  final String orgId;
  final String? leagueId;
  final String? hubId;
  final String name;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final String category;
  final String uploadedBy;
  final String uploadedByName;
  final List<DocumentVersion> versions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Document({
    required this.id,
    required this.orgId,
    this.leagueId,
    this.hubId,
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

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        leagueId: json['leagueId'] as String?,
        hubId: json['hubId'] as String?,
        name: json['name'] as String,
        fileUrl: json['fileUrl'] as String,
        fileType: json['fileType'] as String,
        fileSize: json['fileSize'] as int,
        category: json['category'] as String,
        uploadedBy: json['uploadedBy'] as String,
        uploadedByName: json['uploadedByName'] as String,
        versions: (json['versions'] as List? ?? [])
            .map((v) => DocumentVersion.fromJson(v as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'leagueId': leagueId,
        'hubId': hubId,
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
