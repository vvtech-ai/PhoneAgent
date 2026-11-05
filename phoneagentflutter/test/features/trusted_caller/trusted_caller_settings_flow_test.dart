import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/pump_ui_transitions.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  testWidgets(
    'shared formal settings entry refuses missing SDK and returns',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(const ShellPreviewPage(startSignedIn: true));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('设置'));
      await tester.pumpUntilUiSettled();
      final entry = find.byKey(const Key('settings-trustedCaller'));
      await tester.scrollUntilVisible(entry, 150);
      await tester.tap(entry);
      await tester.pumpUntilUiSettled();
      expect(find.byKey(const Key('settings-trustedCaller')), findsOneWidget);
      expect(find.text('当前环境的可信来电服务暂不可用'), findsOneWidget);
      expect(find.text('正在读取状态'), findsNothing);
      expect(find.byKey(const Key('trusted-caller-open')), findsNothing);
      await tester.tap(entry);
      await tester.pumpUntilUiSettled();
      expect(find.byKey(const Key('settings-trustedCaller')), findsOneWidget);
      expect(find.text('可信来电已开启'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
