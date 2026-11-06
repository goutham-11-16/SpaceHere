import 'space_exception.dart';

class SpaceExceptionParser {
  const SpaceExceptionParser();

  SpaceException parse(Object error) {
    if (error is SpaceException) {
      return error;
    }

    if (error.runtimeType.toString() == 'SocketException') {
      return const SpaceException(
        SpaceErrorKind.networkDropped,
        'Waiting for network signal...',
      );
    }

    final text = error.toString();
    final floodMatch = RegExp(r'FLOOD_WAIT_(\d+)').firstMatch(text);
    if (floodMatch != null) {
      final seconds = int.tryParse(floodMatch.group(1) ?? '') ?? 0;
      return SpaceException(
        SpaceErrorKind.floodWait,
        'Pacing network paths to secure connection stability...',
        waitSeconds: seconds,
      );
    }

    if (text.contains('CHANNEL_INVALID') || text.contains('CHANNEL_PRIVATE')) {
      return const SpaceException(
        SpaceErrorKind.channelDeleted,
        'Vault channel unavailable. Re-initialization is required.',
      );
    }

    if (text.contains('AUTH_KEY_UNREGISTERED') ||
        text.toLowerCase().contains('unauthorized')) {
      return const SpaceException(
        SpaceErrorKind.authKeyUnregistered,
        'Telegram session revoked.',
      );
    }

    return SpaceException(SpaceErrorKind.unknown, text);
  }
}
