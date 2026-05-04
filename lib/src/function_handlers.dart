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

dynamic _sendJson(dynamic context, Map<String, dynamic> data, {int statusCode = 200}) {
  try {
    return (context as dynamic).res.json(data, statusCode);
  } catch (_) {
    return jsonEncode(data);
  }
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
    final isError = line.contains('level=ERROR');
    try {
      if (isError) {
        (context as dynamic).error(line);
      } else {
        (context as dynamic).log(line);
      }
    } catch (_) {
      print(line);
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
  AppwriteLogger? logger;
  try {
    final config = AppwriteConfig.fromEnvironment();
    logger = _buildLogger(context, config.logLevel);

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

    final data = _successResponse(summary: summary, selectedMode: false);
    _sendJson(context, data, statusCode: 200);
    return data;
  } catch (error) {
    logger?.error('function.failed', data: <String, Object?>{'mode': 'all', 'error': error.toString()});
    final data = _errorResponse(error);
    _sendJson(context, data, statusCode: 500);
    return data;
  }
}

Future<Map<String, dynamic>> runDeleteSelectedCollections(dynamic context) async {
  AppwriteLogger? logger;
  try {
    final config = AppwriteConfig.fromEnvironment();
    logger = _buildLogger(context, config.logLevel);

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

    final data = _successResponse(
      summary: summary,
      selectedMode: true,
      collectionsRequested: collectionIds.length,
    );
    _sendJson(context, data, statusCode: 200);
    return data;
  } catch (error) {
    logger?.error(
      'function.failed',
      data: <String, Object?>{'mode': 'selected', 'error': error.toString()},
    );
    final data = _errorResponse(error);
    _sendJson(context, data, statusCode: 500);
    return data;
  }
}
