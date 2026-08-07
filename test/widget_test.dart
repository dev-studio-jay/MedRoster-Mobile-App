import 'package:flutter_test/flutter_test.dart';
import 'package:medroster/main.dart';

void main() {
  testWidgets('MedRoster app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MedRosterApp());
  });
}
