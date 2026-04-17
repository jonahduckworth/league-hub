enum ChatRoomType { league, event, direct }

class ChatRoom {
  final String id;
  final String orgId;
  final String name;
  final ChatRoomType type;
  final String? leagueId;
  final String? hubId;
  final List<String> participants;
  final DateTime createdAt;
  final bool isArchived;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageBy;
  final String? roomIconName;
  final String? roomImageUrl;
  final Map<String, String> participantNames;

  ChatRoom({
    required this.id,
    required this.orgId,
    required this.name,
    required this.type,
    this.leagueId,
    this.hubId,
    required this.participants,
    required this.createdAt,
    required this.isArchived,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageBy,
    this.roomIconName,
    this.roomImageUrl,
    this.participantNames = const {},
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        type: ChatRoomType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ChatRoomType.league,
        ),
        leagueId: json['leagueId'] as String?,
        hubId: json['hubId'] as String?,
        participants: List<String>.from(json['participants'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isArchived: json['isArchived'] as bool? ?? false,
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.parse(json['lastMessageAt'] as String)
            : null,
        lastMessageBy: json['lastMessageBy'] as String?,
        roomIconName: json['roomIconName'] as String?,
        roomImageUrl: json['roomImageUrl'] as String?,
        participantNames:
            Map<String, String>.from(json['participantNames'] as Map? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'name': name,
        'type': type.name,
        'leagueId': leagueId,
        'hubId': hubId,
        'participants': participants,
        'createdAt': createdAt.toIso8601String(),
        'isArchived': isArchived,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'lastMessageBy': lastMessageBy,
        'roomIconName': roomIconName,
        'roomImageUrl': roomImageUrl,
        'participantNames': participantNames,
      };
}
