import 'package:debug_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders debugger title', (WidgetTester tester) async {
    await tester.pumpWidget(const DebugApp());

    expect(find.text('Appwrite Function Debugger'), findsOneWidget);
  });
}