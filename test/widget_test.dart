import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workinai/app_state.dart';
import 'package:workinai/main.dart';

void main() {
  testWidgets('home screen shows the worksheet builder', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();

    await tester.pumpWidget(WorkinAiApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('WorkinAI'), findsOneWidget);
    expect(find.textContaining('build a worksheet'), findsOneWidget);
    expect(find.text('Generate with AI'), findsOneWidget);
    expect(find.text('Recent worksheets'), findsOneWidget);
  });
}
