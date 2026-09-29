import 'package:crownmine/features/review/write_review_screen.dart';
import 'package:crownmine/models/place.dart';
import 'package:crownmine/models/verdict.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  const place = Place(
    id: 'p1',
    name: '測試小吃店',
    address: '台北市大安區',
    types: ['restaurant'],
    primaryType: 'restaurant',
  );

  testWidgets('寫評價頁顯示四種標記且可以選取', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const WriteReviewScreen(place: place)));
    await tester.pumpAndSettle();

    for (final v in Verdict.values) {
      expect(find.text(v.label), findsOneWidget);
    }
    expect(find.text('測試小吃店'), findsOneWidget);

    await tester.ensureVisible(find.text(Verdict.poop.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Verdict.poop.label));
    await tester.pumpAndSettle();
    // 選取後標籤會以該標記的顏色加粗顯示
    final label = tester.widget<Text>(find.text(Verdict.poop.label));
    expect(label.style?.color, Verdict.poop.color);
  });

  testWidgets('沒選標記就送出會提示', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const WriteReviewScreen(place: place)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('送出評價'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('送出評價'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('送出評價'));
    await tester.pump();
    expect(find.text('請先選一個標記'), findsOneWidget);
  });
}
