import 'dart:async';
import 'package:dart_appwrite/dart_appwrite.dart';

// Hardcoded Appwrite credentials
const String _endpoint = 'https://appwrite.appsqueeze.com/';
const String _projectId = '69e0806e001ef211e9dc';
const String _apiKey = 'standard_8079d546d3305480df19cc9dd54433a9c8664bdc6f31dff92c6150d7c6aee240f512dc8b7140973deb5d8783fdb53ed89c7261ba5d89f74a7634ab73583b8408f16d848fb41c88af93aedb5245bdc0bdeb80180ee154025aedb72b3a240a9595fffcc0c4018739aa45550a908900980ccf4b6f2f663d5ec39fc4d6b5c3db29fd';
const String _databaseId = '69e082a500030e6c62c8';
const String _collectionId = 'ai_content';

/// Logger for debugging Appwrite operations
class AppwriteLogger {
  static void info(String message) {
    print('[INFO] ${DateTime.now()}: $message');
  }

  static void debug(String message) {
    print('[DEBUG] ${DateTime.now()}: $message');
  }

  static void error(String message, [dynamic error]) {
    print('[ERROR] ${DateTime.now()}: $message${error != null ? ' | $error' : ''}');
  }
}

/// Client configuration for Appwrite
Client _getClient() {
  final client = Client()
      .setEndpoint(_endpoint)
      .setProject(_projectId)
      .setKey(_apiKey);
  AppwriteLogger.debug('Appwrite client initialized');
  return client;
}

/// Deletes all documents from the specified collection
/// Returns the number of deleted documents
Future<int> deleteAllDocuments() async {
  AppwriteLogger.info('Starting deletion from collection: $_collectionId');

  final databases = Databases(_getClient());
  int deletedCount = 0;
  int batchCount = 0;

  try {
    while (true) {
      batchCount++;
      AppwriteLogger.debug('Fetching batch #$batchCount...');

      final response = await databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _collectionId,
        queries: [Query.limit(100)],
      );

      final documents = response.documents;

      if (documents.isEmpty) {
        AppwriteLogger.info('No more documents found');
        break;
      }

      AppwriteLogger.debug('Found ${documents.length} documents');

      for (final doc in documents) {
        try {
          await databases.deleteDocument(
            databaseId: _databaseId,
            collectionId: _collectionId,
            documentId: doc.$id,
          );
          deletedCount++;
          AppwriteLogger.debug('Deleted: ${doc.$id}');
        } catch (e) {
          AppwriteLogger.error('Failed to delete: ${doc.$id}', e);
        }
      }

      AppwriteLogger.info('Batch #$batchCount: deleted ${documents.length} docs');
    }

    AppwriteLogger.info('Complete. Total deleted: $deletedCount');
    return deletedCount;

  } catch (e) {
    AppwriteLogger.error('Error during deletion', e);
    rethrow;
  }
}

/// Main entry point for Appwrite Function
Future<dynamic> main(final context) async {
  AppwriteLogger.info('Function started');

  try {
    final deletedCount = await deleteAllDocuments();

    return context.res.json({
      'success': true,
      'deletedCount': deletedCount,
      'message': 'Deleted $deletedCount documents'
    });

  } catch (e) {
    AppwriteLogger.error('Function failed', e);

    return context.res.json({
      'success': false,
      'error': e.toString()
    }, statusCode: 500);
  }
}
