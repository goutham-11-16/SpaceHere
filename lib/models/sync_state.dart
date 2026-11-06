import 'space_node.dart';

class SyncState {
  const SyncState({
    required this.schemaVersion,
    required this.exportedAt,
    required this.deviceId,
    required this.channelId,
    required this.nodes,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final String deviceId;
  final String channelId;
  final List<SpaceNode> nodes;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'deviceId': deviceId,
      'channelId': channelId,
      'nodes': nodes.map((node) => node.toJson()).toList(),
    };
  }

  factory SyncState.fromJson(Map<String, dynamic> json) {
    return SyncState(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      deviceId: json['deviceId'] as String,
      channelId: json['channelId'] as String,
      nodes: (json['nodes'] as List<dynamic>? ?? const [])
          .map(
            (nodeJson) => SpaceNode.fromJson(nodeJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
