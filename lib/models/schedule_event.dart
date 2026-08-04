enum ScheduleEventStatus { scheduled, finalGame, removed }

class ScheduleEvent {
  final String id;
  final String orgId;
  final String sourceUid;
  final List<String> teamIds;
  final List<String> hubIds;
  final List<String> leagueIds;
  final String? division;
  final String title;
  final String firstTeamName;
  final String secondTeamName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String? location;
  final String? description;
  final ScheduleEventStatus status;
  final int? firstScore;
  final int? secondScore;
  final bool isActive;

  const ScheduleEvent({
    required this.id,
    required this.orgId,
    required this.sourceUid,
    required this.teamIds,
    required this.hubIds,
    required this.leagueIds,
    this.division,
    required this.title,
    required this.firstTeamName,
    required this.secondTeamName,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    this.location,
    this.description,
    required this.status,
    this.firstScore,
    this.secondScore,
    required this.isActive,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        sourceUid: json['sourceUid'] as String,
        teamIds: List<String>.from(json['teamIds'] as List? ?? []),
        hubIds: List<String>.from(json['hubIds'] as List? ?? []),
        leagueIds: List<String>.from(json['leagueIds'] as List? ?? []),
        division: json['division'] as String?,
        title: json['title'] as String,
        firstTeamName: json['firstTeamName'] as String,
        secondTeamName: json['secondTeamName'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        timezone: json['timezone'] as String? ?? 'America/Edmonton',
        location: json['location'] as String?,
        description: json['description'] as String?,
        status: switch (json['status']) {
          'final' => ScheduleEventStatus.finalGame,
          'removed' => ScheduleEventStatus.removed,
          _ => ScheduleEventStatus.scheduled,
        },
        firstScore: json['firstScore'] as int?,
        secondScore: json['secondScore'] as int?,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'sourceUid': sourceUid,
        'teamIds': teamIds,
        'hubIds': hubIds,
        'leagueIds': leagueIds,
        'division': division,
        'title': title,
        'firstTeamName': firstTeamName,
        'secondTeamName': secondTeamName,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'timezone': timezone,
        'location': location,
        'description': description,
        'status': switch (status) {
          ScheduleEventStatus.scheduled => 'scheduled',
          ScheduleEventStatus.finalGame => 'final',
          ScheduleEventStatus.removed => 'removed',
        },
        'firstScore': firstScore,
        'secondScore': secondScore,
        'isActive': isActive,
      };

  bool isUpcomingAt(DateTime now) => isActive && startsAt.isAfter(now);

  String get cleanFirstTeamName => _cleanTeamName(firstTeamName);
  String get cleanSecondTeamName => _cleanTeamName(secondTeamName);

  static String _cleanTeamName(String value) =>
      value.replaceFirst(RegExp(r'^\d{2}U\s+(?:AAA|AA|A)\s+-\s+'), '').trim();
}
