// Basit bir smoke test: uygulama SharedXIApp ile başlıyor mu ve
// karşılama ekranı doğru render ediliyor mu kontrol eder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_xi/main.dart';

void main() {
  testWidgets('SharedXIApp launches and shows welcome screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SharedXIApp());
    await tester.pump();

    expect(find.text('SHARED XI'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });
}