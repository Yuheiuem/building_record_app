import 'package:building_record_app/app.dart';
import 'package:building_record_app/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('段階0-1の準備画面とバージョンを表示する', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BuildingRecordApp());

    expect(find.text(AppConfig.workingTitle), findsOneWidget);
    expect(find.text(AppConfig.stage), findsOneWidget);
    expect(find.text('技術スパイクの準備'), findsOneWidget);
    expect(find.text('準備完了'), findsOneWidget);
    expect(find.text('作成済み'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
  });

  testWidgets('未実装のGoogleログインボタンは無効である', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BuildingRecordApp());

    final Finder buttonFinder = find.widgetWithText(
      FilledButton,
      'Googleログイン（次の段階で実装）',
    );

    expect(buttonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);
  });
}
