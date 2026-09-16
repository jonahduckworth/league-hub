enum MessageReaction {
  thumbsUp(key: 'thumbsUp', emoji: '👍', label: 'Thumbs up'),
  heart(key: 'heart', emoji: '❤️', label: 'Heart'),
  laugh(key: 'laugh', emoji: '😂', label: 'Laughing'),
  celebrate(key: 'celebrate', emoji: '🎉', label: 'Celebrate'),
  clap(key: 'clap', emoji: '🙌', label: 'Raised hands'),
  fire(key: 'fire', emoji: '🔥', label: 'Fire');

  const MessageReaction({
    required this.key,
    required this.emoji,
    required this.label,
  });

  final String key;
  final String emoji;
  final String label;

  static MessageReaction? fromKey(String key) {
    for (final reaction in values) {
      if (reaction.key == key) return reaction;
    }
    return null;
  }
}

Map<String, List<String>> parseMessageReactions(Object? value) {
  if (value is! Map) return const {};

  final parsed = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || MessageReaction.fromKey(key) == null) continue;
    final userIds = entry.value;
    if (userIds is! List) continue;
    final uniqueIds = userIds.whereType<String>().toSet().toList();
    if (uniqueIds.isNotEmpty) parsed[key] = uniqueIds;
  }
  return parsed;
}
