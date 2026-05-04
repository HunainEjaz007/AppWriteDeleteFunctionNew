import 'dart:convert';

import 'package:http/http.dart' as http;

import 'appwrite_config.dart';
import 'appwrite_logger.dart';

class CollectionDeleteSummary {
  CollectionDeleteSummary({
    required this.collectionId,
    required this.deletedCount,
    required this.errors,
    required this.resourceType,
  });

  final String collectionId;
  final int deletedCount;
  final List<String> errors;
  final String resourceType;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'collectionId': collectionId,
      'resourceType': resourceType,
      'deletedCount': deletedCount,
      'errors': errors,
    };
  }
}

class DeleteExecutionSummary {
  DeleteExecutionSummary({
    required this.databaseId,
    required this.perCollection,
    required this.mode,
  });

  final String databaseId;
  final List<CollectionDeleteSummary> perCollection;
  final String mode;

  int get totalDeleted =>
      perCollection.fold<int>(0, (previousValue, item) => previousValue + item.deletedCount);

  List<String> get errors => perCollection.expand((entry) => entry.errors).toList(growable: false);

  Map<String, Object?> toMap({required bool selectedMode, int? collectionsRequested}) {
    return <String, Object?>{
      'success': true,
      'databaseId': databaseId,
      'mode': mode,
      if (selectedMode) 'collectionsRequested': collectionsRequested ?? perCollection.length,
      if (!selectedMode) 'collectionsProcessed': perCollection.length,
      'totalDeleted': totalDeleted,
      'perCollection': perCollection.map((entry) => entry.toMap()).toList(growable: false),
      'errors': errors,
    };
  }
}

class AppwriteRequestException implements Exception {
  AppwriteRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ResourceRef {
  _ResourceRef({
    required this.id,
    required this.type,
  });

  final String id;
  final String type;
}

class DeletionService {
  DeletionService({
    required this.config,
    required this.logger,
    http.Client? httpClient,
    this.batchSize = 100,
  }) : _httpClient = httpClient ?? http.Client();

  final AppwriteConfig config;
  final AppwriteLogger logger;
  final http.Client _httpClient;
  final int batchSize;

  Future<DeleteExecutionSummary> deleteFixedTable({
    required String databaseId,
    required String tableId,
  }) async {
    final resource = _ResourceRef(id: tableId, type: 'table');
    final summary = await _deleteResource(databaseId: databaseId, resource: resource);
    return DeleteExecutionSummary(
      databaseId: databaseId,
      perCollection: <CollectionDeleteSummary>[summary],
      mode: 'table',
    );
  }

  Future<DeleteExecutionSummary> deleteAllCollections({required String databaseId}) async {
    logger.info('collection.scan.start', data: <String, Object?>{'databaseId': databaseId});

    final resources = await _listAllResources(databaseId);

    logger.info(
      'collection.scan.end',
      data: <String, Object?>{
        'databaseId': databaseId,
        'resources': resources.length,
        'mode': resources.isEmpty ? 'none' : resources.first.type,
      },
    );

    final summaries = <CollectionDeleteSummary>[];
    for (final resource in resources) {
      summaries.add(await _deleteResource(databaseId: databaseId, resource: resource));
    }

    final mode = resources.isEmpty ? 'unknown' : resources.first.type;
    return DeleteExecutionSummary(databaseId: databaseId, perCollection: summaries, mode: mode);
  }

  Future<DeleteExecutionSummary> deleteSelectedCollections({
    required String databaseId,
    required List<String> collectionIds,
  }) async {
    final resources = <_ResourceRef>[];
    for (final collectionId in collectionIds) {
      resources.add(await _detectResource(databaseId: databaseId, resourceId: collectionId));
    }

    final summaries = <CollectionDeleteSummary>[];
    for (final resource in resources) {
      summaries.add(await _deleteResource(databaseId: databaseId, resource: resource));
    }

    final mode = resources.isEmpty ? 'unknown' : resources.first.type;
    return DeleteExecutionSummary(databaseId: databaseId, perCollection: summaries, mode: mode);
  }

  Future<List<_ResourceRef>> _listAllResources(String databaseId) async {
    final tablesResponse = await _get('/tablesdb/$databaseId/tables');
    if (tablesResponse.statusCode == 200) {
      final body = _decodeJsonMap(tablesResponse.body);
      final tables = (body['tables'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((table) => _ResourceRef(id: table[r'$id'].toString(), type: 'table'))
          .toList(growable: false);
      if (tables.isNotEmpty) {
        return tables;
      }
    }

    final collectionsResponse = await _get('/databases/$databaseId/collections');
    if (collectionsResponse.statusCode == 200) {
      final body = _decodeJsonMap(collectionsResponse.body);
      return (body['collections'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((collection) => _ResourceRef(id: collection[r'$id'].toString(), type: 'collection'))
          .toList(growable: false);
    }

    throw AppwriteRequestException(
      'Failed to list tables or collections for database $databaseId. '
      'tablesStatus=${tablesResponse.statusCode} collectionsStatus=${collectionsResponse.statusCode}',
    );
  }

  Future<_ResourceRef> _detectResource({
    required String databaseId,
    required String resourceId,
  }) async {
    final tableRowsResponse = await _get(
      '/tablesdb/$databaseId/tables/$resourceId/rows',
      query: <String, String>{'queries[]': 'limit(1)'},
    );
    if (tableRowsResponse.statusCode == 200) {
      return _ResourceRef(id: resourceId, type: 'table');
    }

    final documentResponse = await _get(
      '/databases/$databaseId/collections/$resourceId/documents',
      query: <String, String>{'queries[]': 'limit(1)'},
    );
    if (documentResponse.statusCode == 200) {
      return _ResourceRef(id: resourceId, type: 'collection');
    }

    throw AppwriteRequestException(
      'Unable to detect resource type for $resourceId in $databaseId. '
      'tableStatus=${tableRowsResponse.statusCode} collectionStatus=${documentResponse.statusCode}',
    );
  }

  Future<CollectionDeleteSummary> _deleteResource({
    required String databaseId,
    required _ResourceRef resource,
  }) async {
    logger.info(
      'resource.delete.start',
      data: <String, Object?>{
        'databaseId': databaseId,
        'resourceId': resource.id,
        'resourceType': resource.type,
      },
    );

    var deletedCount = 0;
    var batch = 0;
    final errors = <String>[];

    while (true) {
      batch++;
      final rowIds = await _listItemIds(
        databaseId: databaseId,
        resource: resource,
      );

      logger.info(
        'batch.fetch',
        data: <String, Object?>{
          'databaseId': databaseId,
          'resourceId': resource.id,
          'resourceType': resource.type,
          'batch': batch,
          'batchSize': rowIds.length,
        },
      );

      if (rowIds.isEmpty) {
        break;
      }

      for (final rowId in rowIds) {
        try {
          await _deleteItem(databaseId: databaseId, resource: resource, itemId: rowId);
          deletedCount++;
        } catch (error) {
          final message =
              'resource=${resource.id} type=${resource.type} item=$rowId error=$error';
          errors.add(message);
          logger.error(
            'item.delete.failed',
            data: <String, Object?>{
              'databaseId': databaseId,
              'resourceId': resource.id,
              'resourceType': resource.type,
              'itemId': rowId,
              'error': error.toString(),
            },
          );
        }
      }
    }

    logger.info(
      'resource.delete.end',
      data: <String, Object?>{
        'databaseId': databaseId,
        'resourceId': resource.id,
        'resourceType': resource.type,
        'deletedCount': deletedCount,
        'errorCount': errors.length,
      },
    );

    return CollectionDeleteSummary(
      collectionId: resource.id,
      deletedCount: deletedCount,
      errors: errors,
      resourceType: resource.type,
    );
  }

  Future<List<String>> _listItemIds({
    required String databaseId,
    required _ResourceRef resource,
  }) async {
    final path = resource.type == 'table'
        ? '/tablesdb/$databaseId/tables/${resource.id}/rows'
        : '/databases/$databaseId/collections/${resource.id}/documents';

    final response = await _get(
      path,
      query: <String, String>{'queries[]': 'limit($batchSize)'},
    );

    if (response.statusCode != 200) {
      throw AppwriteRequestException(
        'Failed listing items from ${resource.type} ${resource.id}. '
        'status=${response.statusCode} body=${response.body}',
      );
    }

    final body = _decodeJsonMap(response.body);
    final key = resource.type == 'table' ? 'rows' : 'documents';
    return (body[key] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((item) => item[r'$id'].toString())
        .toList(growable: false);
  }

  Future<void> _deleteItem({
    required String databaseId,
    required _ResourceRef resource,
    required String itemId,
  }) async {
    final path = resource.type == 'table'
        ? '/tablesdb/$databaseId/tables/${resource.id}/rows/$itemId'
        : '/databases/$databaseId/collections/${resource.id}/documents/$itemId';

    final response = await _delete(path);
    if (response.statusCode != 204) {
      throw AppwriteRequestException(
        'Failed deleting item $itemId from ${resource.type} ${resource.id}. '
        'status=${response.statusCode} body=${response.body}',
      );
    }
  }

  Future<http.Response> _get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query: query);
    logger.info('appwrite.request', data: <String, Object?>{'method': 'GET', 'url': uri.toString()});
    final response = await _httpClient.get(uri, headers: _headers());
    logger.info(
      'appwrite.response',
      data: <String, Object?>{
        'method': 'GET',
        'url': uri.toString(),
        'statusCode': response.statusCode,
        'bodyPreview': _preview(response.body),
      },
    );
    return response;
  }

  Future<http.Response> _delete(String path) async {
    final uri = _buildUri(path);
    logger.info('appwrite.request', data: <String, Object?>{'method': 'DELETE', 'url': uri.toString()});
    final response = await _httpClient.delete(uri, headers: _headers());
    logger.info(
      'appwrite.response',
      data: <String, Object?>{
        'method': 'DELETE',
        'url': uri.toString(),
        'statusCode': response.statusCode,
        'bodyPreview': _preview(response.body),
      },
    );
    return response;
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final normalizedBase = config.endpoint.replaceAll(RegExp(r'/+$'), '');
    final base = normalizedBase.endsWith('/v1') ? normalizedBase : '$normalizedBase/v1';
    final uri = Uri.parse('$base$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    return <String, String>{
      'X-Appwrite-Project': config.projectId,
      'X-Appwrite-Key': config.apiKey,
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decodeJsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw AppwriteRequestException('Unexpected JSON payload: $raw');
  }

  String _preview(String body) {
    if (body.length <= 300) {
      return body;
    }
    return '${body.substring(0, 300)}...';
  }
}
