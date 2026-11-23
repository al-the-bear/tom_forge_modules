import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit_example/main.dart';

void main() {
  testWidgets('lists the actions of the kit as text', (tester) async {
    await tester.pumpWidget(const KitExampleApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Tom Forge Kit: 2 actions'), findsOneWidget);
    expect(find.text('example.hello: Say hello'), findsOneWidget);
    expect(find.text('example.goodbye: Say goodbye'), findsOneWidget);
  });
}
