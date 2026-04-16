import 'package:app_write_fun/app_write_fun.dart';

void main() async {
  // Example: Delete all documents from the configured collection
  // Make sure to update the hardcoded credentials in the library first!

  print('Starting document deletion example...');

  try {
    final deletedCount = await deleteAllDocuments();
    print('Successfully deleted $deletedCount documents');
  } catch (e) {
    print('Error: $e');
  }
}
