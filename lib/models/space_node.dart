import 'package:uuid/uuid.dart';

class SpaceNode {
  SpaceNode({
    String? uuid,
    required this.name,
    required this.parentUuid,
    required this.mimeType,
    required this.isFolder,
    required this.sizeBytes,
    required this.chunkMessageIds,
    required this.createdAt,
    required this.updatedAt,
    this.ivBase64,
    this.authTagBase64,
    this.isDeleted = false,
    this.isFavorite = false,
    List<String>? tags,
    this.originDevice = 'Local Workspace',
    this.originPlatform = 'unknown',
  }) : uuid = uuid ?? const Uuid().v4(),
       tags = tags ?? const [];

  final String uuid;
  final String name;
  final String? parentUuid;
  final String mimeType;
  final bool isFolder;
  final int sizeBytes;
  final List<int> chunkMessageIds;
  final String? ivBase64;
  final String? authTagBase64;
  final bool isDeleted;
  final bool isFavorite;
  final List<String> tags;
  final String originDevice;
  final String originPlatform;
  final DateTime createdAt;
  final DateTime updatedAt;

  SpaceNode copyWith({
    String? name,
    String? parentUuid,
    String? mimeType,
    bool? isFolder,
    int? sizeBytes,
    List<int>? chunkMessageIds,
    String? ivBase64,
    String? authTagBase64,
    bool? isDeleted,
    bool? isFavorite,
    List<String>? tags,
    String? originDevice,
    String? originPlatform,
    DateTime? updatedAt,
  }) {
    return SpaceNode(
      uuid: uuid,
      name: name ?? this.name,
      parentUuid: parentUuid ?? this.parentUuid,
      mimeType: mimeType ?? this.mimeType,
      isFolder: isFolder ?? this.isFolder,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      chunkMessageIds: chunkMessageIds ?? this.chunkMessageIds,
      ivBase64: ivBase64 ?? this.ivBase64,
      authTagBase64: authTagBase64 ?? this.authTagBase64,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      originDevice: originDevice ?? this.originDevice,
      originPlatform: originPlatform ?? this.originPlatform,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'parentUuid': parentUuid,
      'name': name,
      'mimeType': mimeType,
      'isFolder': isFolder,
      'sizeBytes': sizeBytes,
      'chunkMessageIds': chunkMessageIds,
      'ivBase64': ivBase64,
      'authTagBase64': authTagBase64,
      'isDeleted': isDeleted,
      'isFavorite': isFavorite,
      'tags': tags,
      'originDevice': originDevice,
      'originPlatform': originPlatform,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SpaceNode.fromJson(Map<String, dynamic> json) {
    return SpaceNode(
      uuid: json['uuid'] as String?,
      parentUuid: json['parentUuid'] as String?,
      name: json['name'] as String,
      mimeType: json['mimeType'] as String,
      isFolder: json['isFolder'] as bool? ?? false,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      chunkMessageIds: (json['chunkMessageIds'] as List<dynamic>? ?? const [])
          .map((value) => value as int)
          .toList(),
      ivBase64: json['ivBase64'] as String?,
      authTagBase64: json['authTagBase64'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      originDevice: json['originDevice'] as String? ?? 'Local Workspace',
      originPlatform: json['originPlatform'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
