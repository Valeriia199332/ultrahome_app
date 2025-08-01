// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrahome_app/main.dart';

void main() {
  testWidgets('AppBar displays UltraHome Dashboard', (WidgetTester tester) async {
    // Рендерим только MaterialApp с Вашим виджетом в home,
    // чтобы не запускать initState и WebView.
    await tester.pumpWidget(
      const MaterialApp(
        home: AutoLoginWebView(),
      ),
    );

    // Однократный pump для отрисовки AppBar
    await tester.pump();

    // Проверяем, что AppBar с нужным заголовком найден
    expect(find.text('UltraHome Dashboard'), findsOneWidget);
  });
}

