/// Represents a Firestore write operation queued for offline replay.
class QueuedMutation {
  final String id;
  final String method;
  final Map<String, dynamic> params;
  final DateTime createdAt;
  int retryCount;

  QueuedMutation({
    required this.id,
    required this.method,
    required this.params,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory QueuedMutation.fromJson(Map<String, dynamic> json) => QueuedMutation(
        id: json['id'] as String,
        method: json['method'] as String,
        params: Map<String, dynamic>.from(json['params'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'params': params,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  QueuedMutation copyWith({int? retryCount}) => QueuedMutation(
        id: id,
        method: method,
        params: params,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );

  @override
  String toString() =>
      'QueuedMutation(id: $id, method: $method, retries: $retryCount)';
}
