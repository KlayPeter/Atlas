import 'package:atlas_app/app/atlas_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Atlas opens to the recent reading shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtlasApp()));
    await tester.pumpAndSettle();

    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('打开文件'), findsOneWidget);
  });

  testWidgets('settings route exposes theme controls', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtlasApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('阅读外观'), findsOneWidget);
  });
}
