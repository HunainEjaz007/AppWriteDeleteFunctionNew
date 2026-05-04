import 'dart:convert';

import 'package:dart_appwrite/dart_appwrite.dart';

import 'appwrite_config.dart';
import 'appwrite_logger.dart';
import 'deletion_service.dart';

Map<String, dynamic> _successResponse({
  required DeleteExecutionSummary summary,
  required bool selectedMode,
  int? collectionsRequested,
}) {
  return summary.toMap(
    selectedMode: selectedMode,
    collectionsRequested: collectionsRequested,
  );
}

Map<String, dynamic> _errorResponse(Object error) {
  return <String, dynamic>{
    'success': false,
    'error': error.toString(),
  };
}

Map<String, dynamic> _extractPayload(dynamic context) {
  if (context is Map<String, dynamic>) {
    final payload = context['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is String && payload.trim().isNotEmpty) {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
  }

  final dynamic req = _readProperty(context, 'req');
  if (req != null) {
    final dynamic body = _readProperty(req, 'body');
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is String && body.trim().isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
  }

  return <String, dynamic>{};
}

dynamic _readProperty(dynamic object, String key) {
  if (object == null) {
    return null;
  }
  if (object is Map<String, dynamic>) {
    return object[key];
  }

  try {
    return (object as dynamic).toJson()[key];
  } catch (_) {
    return null;
  }
}

AppwriteLogger _buildLogger(dynamic context, String rawLevel) {
  void writer(String line) {
    print(line);
    try {
      final dynamic logger = _readProperty(context, 'log');
      if (logger is Function) {
        logger(line);
      }
    } catch (_) {
      // Ignore context logging failures; stdout logs are still preserved.
    }
  }

  return AppwriteLogger(
    minLevel: AppwriteLogger.parseLevel(rawLevel),
    onWrite: writer,
  );
}

Client _buildClient(AppwriteConfig config) {
  return Client()
      .setEndpoint(config.endpoint)
      .setProject(config.projectId)
      .setKey(config.apiKey);
}

Future<Map<String, dynamic>> runDeleteAllCollections(dynamic context) async {
  try {
    final config = AppwriteConfig.fromEnvironment();
    final logger = _buildLogger(context, config.logLevel);

    logger.info('function.start', data: <String, Object?>{'mode': 'all'});
    logger.info('config.validated', data: <String, Object?>{'databaseId': config.databaseId});

    final service = DeletionService(
      databases: Databases(_buildClient(config)),
      logger: logger,
    );

    final summary = await service.deleteAllCollections(databaseId: config.databaseId);

    logger.info(
      'function.end',
      data: <String, Object?>{
        'mode': 'all',
        'databaseId': config.databaseId,
        'collectionsProcessed': summary.perCollection.length,
        'totalDeleted': summary.totalDeleted,
      },
    );

    return _successResponse(summary: summary, selectedMode: false);
  } catch (error) {
    return _errorResponse(error);
  }
}

Future<Map<String, dynamic>> runDeleteSelectedCollections(dynamic context) async {
  try {
    final config = AppwriteConfig.fromEnvironment();
    final logger = _buildLogger(context, config.logLevel);

    logger.info('function.start', data: <String, Object?>{'mode': 'selected'});
    logger.info('config.validated', data: <String, Object?>{'databaseId': config.databaseId});

    final payload = _extractPayload(context);
    final collectionIds = (payload['collectionIds'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => item.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (collectionIds.isEmpty) {
      throw ArgumentError('Request payload must include non-empty collectionIds array.');
    }

    final service = DeletionService(
      databases: Databases(_buildClient(config)),
      logger: logger,
    );

    final summary = await service.deleteSelectedCollections(
      databaseId: config.databaseId,
      collectionIds: collectionIds,
    );

    logger.info(
      'function.end',
      data: <String, Object?>{
        'mode': 'selected',
        'databaseId': config.databaseId,
        'collectionsRequested': collectionIds.length,
        'totalDeleted': summary.totalDeleted,
      },
    );

    return _successResponse(
      summary: summary,
      selectedMode: true,
      collectionsRequested: collectionIds.length,
    );
  } catch (error) {
    return _errorResponse(error);
  }
}