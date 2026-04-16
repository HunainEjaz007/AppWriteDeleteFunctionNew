import 'package:app_write_fun/main.dart';
import 'package:test/test.dart';

void main() {
  group('AppwriteLogger tests', () {
    test('Logger methods exist', () {
      // Verify logger methods don't throw
      expect(() => AppwriteLogger.info('test'), returnsNormally);
      expect(() => AppwriteLogger.debug('test'), returnsNormally);
      expect(() => AppwriteLogger.error('test'), returnsNormally);
    });
  });
}
