import 'package:dart_appwrite/dart_appwrite.dart';

// Hardcoded Appwrite credentials - replace with your actual values
const String _endpoint = 'https://cloud.appwrite.io/v1';
const String _projectId = 'YOUR_PROJECT_ID';
const String _apiKey = 'YOUR_API_KEY';
const String _databaseId = 'YOUR_DATABASE_ID';
const String _collectionId = 'YOUR_COLLECTION_ID';

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
class AppwriteConfig {
  static Client get client {
    final client = Client()
        .setEndpoint(_endpoint)
        .setProject(_projectId)
        .setKey(_apiKey);
    AppwriteLogger.debug('Appwrite client initialized with endpoint: $_endpoint');
    return client;
  }
}

/// Deletes all documents from the specified collection
/// Returns the number of deleted documents
Future<int> deleteAllDocuments() async {
  AppwriteLogger.info('Starting deletion of all documents from collection: $_collectionId');

  final databases = Databases(AppwriteConfig.client);
  int deletedCount = 0;
  int batchCount = 0;

  try {
    // Query all documents in batches
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
        AppwriteLogger.info('No more documents found. Total batches: $batchCount');
        break;
      }

      AppwriteLogger.debug('Found ${documents.length} documents in batch #$batchCount');

      // Delete each document in the batch
      for (final doc in documents) {
        try {
          await databases.deleteDocument(
            databaseId: _databaseId,
            collectionId: _collectionId,
            documentId: doc.$id,
          );
          deletedCount++;
          AppwriteLogger.debug('Deleted document: ${doc.$id}');
        } catch (e) {
          AppwriteLogger.error('Failed to delete document: ${doc.$id}', e);
        }
      }

      AppwriteLogger.info('Batch #$batchCount completed. Deleted ${documents.length} documents in this batch');
    }

    AppwriteLogger.info('Deletion complete. Total documents deleted: $deletedCount');
    return deletedCount;

  } catch (e) {
    AppwriteLogger.error('Error during document deletion', e);
    rethrow;
  }
}
