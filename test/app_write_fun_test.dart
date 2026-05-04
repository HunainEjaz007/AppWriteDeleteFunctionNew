import 'package:app_write_fun/src/appwrite_config.dart';
import 'package:app_write_fun/src/appwrite_logger.dart';
import 'package:test/test.dart';

void main() {
  group('AppwriteConfig', () {
    test('throws when required vars are missing', () {
      expect(
        () => AppwriteConfig.fromEnvironment(<String, String>{}),
        throwsA(isA<AppwriteConfigException>()),
      );
    });

    test('loads required vars and default log level', () {
      final config = AppwriteConfig.fromEnvironment(<String, String>{
        'APPWRITE_ENDPOINT': 'https://example.appwrite.io/v1',
        'APPWRITE_PROJECT_ID': 'project_123',
        'APPWRITE_API_KEY': 'key_abc',
        'APPWRITE_DATABASE_ID': 'database_456',
      });

      expect(config.endpoint, 'https://example.appwrite.io/v1');
      expect(config.projectId, 'project_123');
      expect(config.apiKey, 'key_abc');
      expect(config.databaseId, 'database_456');
      expect(config.logLevel, 'INFO');
    });

    test('honors custom log level', () {
      final config = AppwriteConfig.fromEnvironment(<String, String>{
        'APPWRITE_ENDPOINT': 'https://example.appwrite.io/v1',
        'APPWRITE_PROJECT_ID': 'project_123',
        'APPWRITE_API_KEY': 'key_abc',
        'APPWRITE_DATABASE_ID': 'database_456',
        'LOG_LEVEL': 'debug',
      });

      expect(config.logLevel, 'DEBUG');
    });
  });

  group('AppwriteLogger', () {
    test('filters below minimum level', () {
      final lines = <String>[];
      final logger = AppwriteLogger(minLevel: LogLevel.info, onWrite: lines.add);

      logger.debug('debug.ignored');
      logger.info('info.logged', data: <String, Object?>{'key': 'value'});

      expect(lines.length, 1);
      expect(lines.first, contains('level=INFO'));
      expect(lines.first, contains('operation=info.logged'));
      expect(lines.first, contains('key=value'));
    });

    test('parse level supports expected values', () {
      expect(AppwriteLogger.parseLevel('DEBUG'), LogLevel.debug);
      expect(AppwriteLogger.parseLevel('INFO'), LogLevel.info);
      expect(AppwriteLogger.parseLevel('WARN'), LogLevel.warn);
      expect(AppwriteLogger.parseLevel('ERROR'), LogLevel.error);
      expect(AppwriteLogger.parseLevel('unknown'), LogLevel.info);
    });
  });
}