import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/features/incident/domain/entities/fix_flow.dart';
import 'package:sentinel/features/incident/presentation/analysis/widgets/fix_flow_row.dart';

void main() {
  const longTitleFlow = FixFlow(
    id: 'flow-1',
    title: 'Restart the connection pool and verify downstream health checks',
    confidence: 0.87,
    isAttempted: false,
    checklistItems: [],
  );

  Widget wrap(Widget child, Size size) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('mobile width: title row contains no Recommended badge or confidence text',
      (tester) async {
    await tester.pumpWidget(wrap(
      FixFlowRow(
        fixFlow: longTitleFlow,
        index: 0,
        isSelected: false,
        isLoading: false,
        isRecommended: true,
        onTap: () {},
      ),
      const Size(360, 800),
    ));

    expect(find.textContaining('Restart the connection pool'), findsOneWidget);

    // Recommended badge and confidence text must still render, just not
    // sharing a Row with the title (verified by absence of overflow/clip
    // errors and presence of both pieces of text on screen).
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('87% confidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop width: title, Recommended, and confidence all render in one pass',
      (tester) async {
    await tester.pumpWidget(wrap(
      FixFlowRow(
        fixFlow: longTitleFlow,
        index: 0,
        isSelected: false,
        isLoading: false,
        isRecommended: true,
        onTap: () {},
      ),
      const Size(1400, 900),
    ));

    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('87% confidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
