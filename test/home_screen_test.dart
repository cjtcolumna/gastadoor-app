import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/app.dart';

void main() {
  testWidgets('home screen shows setup hint without Supabase', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GastaDoorApp()));
    await tester.pumpAndSettle();

    expect(find.text('GastaDoor'), findsOneWidget);
    expect(find.text('Supabase is not configured'), findsOneWidget);
  });
}
