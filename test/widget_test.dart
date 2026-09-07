import 'package:flutter_test/flutter_test.dart';
import 'package:docketflow/main.dart';

void main() {
  testWidgets('DocketFlowApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DocketFlowApp());
    expect(find.text('DocketFlow'), findsOneWidget);
  });
}
