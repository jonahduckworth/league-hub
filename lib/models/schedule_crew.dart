class ScheduleCrewMember {
  final String name;
  final String role;

  const ScheduleCrewMember({required this.name, required this.role});

  factory ScheduleCrewMember.fromJson(Map<String, dynamic> json) =>
      ScheduleCrewMember(
        name: (json['name'] as String? ?? '').trim(),
        role: (json['role'] as String? ?? '').trim(),
      );
}

class ScheduleCrew {
  final String eventId;
  final List<ScheduleCrewMember> members;

  const ScheduleCrew({required this.eventId, required this.members});

  factory ScheduleCrew.fromJson(Map<String, dynamic> json) => ScheduleCrew(
        eventId: json['eventId'] as String,
        members: (json['members'] as List? ?? const [])
            .whereType<Map>()
            .map((item) =>
                ScheduleCrewMember.fromJson(Map<String, dynamic>.from(item)))
            .where((member) => member.name.isNotEmpty)
            .toList(),
      );
}
