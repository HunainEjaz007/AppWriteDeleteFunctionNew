import 'dart:io';

class AppwriteConfigException implements Exception {
  AppwriteConfigException(this.message);
  final String message;

  @override
  String toString() => 'AppwriteConfigException: $message';
}

class AppwriteConfig {
  AppwriteConfig({
    required this.endpoint,
    required this.projectId,
    required this.apiKey,
    required this.databaseId,
    required this.logLevel,
  });

  final String endpoint;
  final String projectId;
  final String apiKey;
  final String databaseId;
  final String logLevel;

  static AppwriteConfig fromEnvironment([Map<String, String>? overrides]) {
    final env = overrides ?? Platform.environment;

    String read(String key) => (env[key] ?? '').trim();

    final endpoint = read('APPWRITE_ENDPOINT');
    final projectId = read('APPWRITE_PROJECT_ID');
    final apiKey = read('APPWRITE_API_KEY');
    final databaseId = read('APPWRITE_DATABASE_ID');
    final logLevelRaw = read('LOG_LEVEL');
    final logLevel = logLevelRaw.isEmpty ? 'INFO' : logLevelRaw.toUpperCase();

    final missing = <String>[];
    if (endpoint.isEmpty) missing.add('APPWRITE_ENDPOINT');
    if (projectId.isEmpty) missing.add('APPWRITE_PROJECT_ID');
    if (apiKey.isEmpty) missing.add('APPWRITE_API_KEY');
    if (databaseId.isEmpty) missing.add('APPWRITE_DATABASE_ID');

    if (missing.isNotEmpty) {
      throw AppwriteConfigException('Missing required environment variables: ${missing.join(', ')}');
    }

    return AppwriteConfig(
      endpoint: endpoint,
      projectId: projectId,
      apiKey: apiKey,
      databaseId: databaseId,
      logLevel: logLevel,
    );
  }
}