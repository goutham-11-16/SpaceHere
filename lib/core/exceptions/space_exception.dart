enum SpaceErrorKind {
  floodWait,
  networkDropped,
  channelDeleted,
  authKeyUnregistered,
  unknown,
}

class SpaceException implements Exception {
  const SpaceException(this.kind, this.message, {this.waitSeconds});

  final SpaceErrorKind kind;
  final String message;
  final int? waitSeconds;

  @override
  String toString() => 'SpaceException($kind, $message)';
}
