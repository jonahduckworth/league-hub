class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? thumbnailUrl;

  LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.thumbnailUrl,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
        url: json['url'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
      };
}

class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String? text;
  final String? mediaUrl;
  final String? mediaType;
  final LinkPreview? linkPreview;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final List<String> readBy;

  Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.text,
    this.mediaUrl,
    this.mediaType,
    this.linkPreview,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    required this.readBy,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        chatRoomId: json['chatRoomId'] as String,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        text: json['text'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        mediaType: json['mediaType'] as String?,
        linkPreview: json['linkPreview'] != null
            ? LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
        deleted: json['deleted'] as bool? ?? false,
        readBy: List<String>.from(json['readBy'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatRoomId': chatRoomId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'linkPreview': linkPreview?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        'deleted': deleted,
        'readBy': readBy,
      };
}
