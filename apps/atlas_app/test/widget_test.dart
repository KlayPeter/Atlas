import 'package:atlas_app/app/atlas_app.dart';
import 'package:atlas_app/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream.empty(),
    );
  });

  testWidgets('Atlas opens to the recent reading shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtlasApp()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('打开文件'), findsOneWidget);
  });

  testWidgets('settings route exposes theme controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('阅读外观'), findsOneWidget);
    expect(find.text('阅读排版'), findsOneWidget);
    expect(find.text('测试 Atlas BFF / AI 连通性'), findsNothing);
  });
}
