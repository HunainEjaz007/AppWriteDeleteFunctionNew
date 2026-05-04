enum LogLevel {
  debug,
  info,
  warn,
  error,
}

class AppwriteLogger {
  AppwriteLogger({
    required this.minLevel,
    this.onWrite,
  });

  final LogLevel minLevel;
  final void Function(String message)? onWrite;

  static LogLevel parseLevel(String raw) {
    switch (raw.toUpperCase()) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'WARN':
        return LogLevel.warn;
      case 'ERROR':
        return LogLevel.error;
      case 'INFO':
      default:
        return LogLevel.info;
    }
  }

  void debug(String operation, {Map<String, Object?> data = const {}}) {
    _log(LogLevel.debug, operation, data);
  }

  void info(String operation, {Map<String, Object?> data = const {}}) {
    _log(LogLevel.info, operation, data);
  }

  void warn(String operation, {Map<String, Object?> data = const {}}) {
    _log(LogLevel.warn, operation, data);
  }

  void error(String operation, {Map<String, Object?> data = const {}}) {
    _log(LogLevel.error, operation, data);
  }

  void _log(LogLevel level, String operation, Map<String, Object?> data) {
    if (level.index < minLevel.index) {
      return;
    }

    final payload = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level.name.toUpperCase(),
      'operation': operation,
      ...data,
    };

    final line = payload.entries.map((entry) => '${entry.key}=${entry.value}').join(' ');
    if (onWrite != null) {
      onWrite!(line);
      return;
    }
    print(line);
  }
}