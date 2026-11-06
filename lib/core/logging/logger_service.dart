import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error, fatal }

class LoggerService {
  LoggerService._();

  static final LoggerService instance = LoggerService._();

  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = '[${level.name.toUpperCase()}][$timestamp][$tag]';
    final output = '$prefix $message';

    developer.log(
      output,
      name: tag,
      level: _levelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );

    if (level == LogLevel.error || level == LogLevel.fatal) {
      // ignore: avoid_print
      print('🔴 $output ${error != null ? "\nError: $error" : ""}');
    } else if (level == LogLevel.warning) {
      // ignore: avoid_print
      print('🟡 $output');
    } else {
      // ignore: avoid_print
      print('🔵 $output');
    }
  }

  void debug(String tag, String message) => log(LogLevel.debug, tag, message);
  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void warning(String tag, String message) =>
      log(LogLevel.warning, tag, message);
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);
  void fatal(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.fatal, tag, message, error: error, stackTrace: stackTrace);

  int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.fatal:
        return 1200;
    }
  }
}
