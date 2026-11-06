class TelegramConfig {
  static const int apiId = int.fromEnvironment(
    'TELEGRAM_API_ID',
    defaultValue: 33289586,
  );
  static const String apiHash = String.fromEnvironment(
    'TELEGRAM_API_HASH',
    defaultValue: '5b243015335fea7af9c3ed59b5953a1c',
  );
  static const String defaultPhone = String.fromEnvironment(
    'TELEGRAM_DEFAULT_PHONE',
    defaultValue: '',
  );
  static const String vaultChannelTitle = '[DO NOT DELETE] SpaceHere Vault';
  static const String vaultChannelDescription =
      'SpaceHERE Virtual File System Encrypted Storage Vault';
}
