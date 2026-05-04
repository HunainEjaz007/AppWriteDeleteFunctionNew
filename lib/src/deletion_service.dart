import 'package:dart_appwrite/dart_appwrite.dart';

import 'appwrite_logger.dart';

class CollectionDeleteSummary {
  CollectionDeleteSummary({
    required this.collectionId,
    required this.deletedCount,
    required this.errors,
  });

  final String collectionId;
  final int deletedCount;
  final List<String> errors;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'collectionId': collectionId,
      'deletedCount': deletedCount,
      'errors': errors,
    };
  }
}

class DeleteExecutionSummary {
  DeleteExecutionSummary({
    required this.databaseId,
    required this.perCollection,
  });

  final String databaseId;
  final List<CollectionDeleteSummary> perCollection;

  int get totalDeleted =>
      perCollection.fold<int>(0, (previousValue, item) => previousValue + item.deletedCount);

  List<String> get errors => perCollection.expand((entry) => entry.errors).toList(growable: false);

  Map<String, Object?> toMap({required bool selectedMode, int? collectionsRequested}) {
    return <String, Object?>{
      'success': true,
      'databaseId': databaseId,
      if (selectedMode) 'collectionsRequested': collectionsRequested ?? perCollection.length,
      if (!selectedMode) 'collectionsProcessed': perCollection.length,
      'totalDeleted': totalDeleted,
      'perCollection': perCollection.map((entry) => entry.toMap()).toList(growable: false),
      'errors': errors,
    };
  }
}

class DeletionService {
  DeletionService({
    required this.databases,
    required this.logger,
    this.batchSize = 100,
  });

  final Databases databases;
  final AppwriteLogger logger;
  final int batchSize;

  Future<DeleteExecutionSummary> deleteAllCollections({required String databaseId}) async {
    logger.info('collection.scan.start', data: <String, Object?>{'databaseId': databaseId});

    final list = await databases.listCollections(databaseId: databaseId);
    final collectionIds = list.collections.map((collection) => collection.$id).toList(growable: false);

    logger.info(
      'collection.scan.end',
      data: <String, Object?>{'databaseId': databaseId, 'collections': collectionIds.length},
    );

    return deleteSelectedCollections(databaseId: databaseId, collectionIds: collectionIds);
  }

  Future<DeleteExecutionSummary> deleteSelectedCollections({
    required String databaseId,
    required List<String> collectionIds,
  }) async {
    final summaries = <CollectionDeleteSummary>[];

    for (final collectionId in collectionIds) {
      final summary = await _deleteCollectionDocuments(databaseId: databaseId, collectionId: collectionId);
      summaries.add(summary);
    }

    return DeleteExecutionSummary(databaseId: databaseId, perCollection: summaries);
  }

  Future<CollectionDeleteSummary> _deleteCollectionDocuments({
    required String databaseId,
    required String collectionId,
  }) async {
    logger.info(
      'collection.delete.start',
      data: <String, Object?>{'databaseId': databaseId, 'collectionId': collectionId},
    );

    var deletedCount = 0;
    var batch = 0;
    final errors = <String>[];

    while (true) {
      batch++;
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: <String>[Query.limit(batchSize)],
      );

      final documents = response.documents;
      logger.debug(
        'batch.fetch',
        data: <String, Object?>{
          'databaseId': databaseId,
          'collectionId': collectionId,
          'batch': batch,
          'batchSize': documents.length,
        },
      );

      if (documents.isEmpty) {
        break;
      }

      for (final doc in documents) {
        try {
          await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: doc.$id,
          );
          deletedCount++;
        } catch (error) {
          final entry = 'collection=$collectionId document=${doc.$id} error=$error';
          errors.add(entry);
          logger.error(
            'document.delete.failed',
            data: <String, Object?>{
              'databaseId': databaseId,
              'collectionId': collectionId,
              'documentId': doc.$id,
              'error': error.toString(),
            },
          );
        }
      }
    }

    logger.info(
      'collection.delete.end',
      data: <String, Object?>{
        'databaseId': databaseId,
        'collectionId': collectionId,
        'deletedCount': deletedCount,
        'errorCount': errors.length,
      },
    );

    return CollectionDeleteSummary(
      collectionId: collectionId,
      deletedCount: deletedCount,
      errors: errors,
    );
  }
}