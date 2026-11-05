import 'package:flutter/material.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_preset_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dial_permission_preview_page.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_permission_host.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'native location prompt short large text and backdrop $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const DialPermissionPreviewPage(),
          ),
        );
        await tester.ensureVisible(find.text('Android 拒绝后去设置'));
        await tester.tap(find.text('Android 拒绝后去设置'));
        await tester.pumpAndSettle();
        final prompt = find.byType(NativeBusinessDialog);
        expect(prompt, findsOneWidget);
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, Colors.white);
        expect(
          (dialog.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(22),
        );
        final action = find.widgetWithText(TextButton, '暂不开启');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(prompt, findsNothing);
        expect(find.textContaining('location:request'), findsNothing);
        expect(find.text('阶段：ready'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(prompt, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('host disposal while dialog is open does not pop another route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const DialPermissionPreviewPage(),
      ),
    );
    await tester.tap(find.text('Android 拒绝后去设置'));
    await tester.pumpAndSettle();
    expect(find.byType(NativeBusinessDialog), findsOneWidget);
    final oldRoute = ModalRoute.of(
      tester.element(find.byType(DialPermissionHost)),
    )!;
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('new owner')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.removeRoute(oldRoute);
    await tester.pumpAndSettle();
    expect(find.text('new owner'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('拨号权限演练'), findsOneWidget);
    expect(find.byType(NativeBusinessDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String scenario) async {
    await tester.pumpWidget(
      const MaterialApp(home: DialPermissionPreviewPage()),
    );
    await tap(tester, find.text(scenario));
    expect(find.byType(NativeBusinessDialog), findsOneWidget);
    expect(find.textContaining('callLog:request'), findsNothing);
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'nested presets permission dialog and settings return at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await open(tester, 'Android 拒绝后去设置');
        await tap(tester, find.widgetWithText(TextButton, '开启位置权限'));
        expect(find.byType(NativeBusinessDialog), findsNothing);
        expect(find.textContaining('callLog:request'), findsOneWidget);
        await tap(tester, find.text('打开拨号配置'));
        await tap(tester, find.byKey(const Key('translation-enabled')));
        expect(find.text('需要位置权限'), findsOneWidget);
        await tap(tester, find.text('前往系统设置'));
        expect(find.text('从系统设置返回'), findsNothing);
        expect(find.byType(NativeBusinessDialog), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(NativeBusinessDialog), findsNothing);
        expect(find.text('实时翻译通话'), findsOneWidget);
        expect(
          tester
              .widget<NativeTranslationPresetSwitchRow>(
                find.byKey(const Key('translation-enabled')),
              )
              .value,
          isTrue,
        );
        await tap(tester, find.byKey(const Key('translation-presets-close')));
        expect(find.text('阶段：ready'), findsOneWidget);
        await tap(tester, find.text('重置 App 位置提示（保留系统事实）'));
        expect(find.byType(NativeBusinessDialog), findsNothing);
        expect(find.textContaining('系统位置：granted'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'iOS retains its existing settings return dialog',
    (tester) async {
      await open(tester, 'Android 拒绝后去设置');
      await tap(tester, find.widgetWithText(TextButton, '开启位置权限'));
      await tap(tester, find.text('打开拨号配置'));
      await tap(tester, find.byKey(const Key('translation-enabled')));
      await tap(tester, find.text('前往系统设置'));
      expect(find.text('从系统设置返回'), findsOneWidget);
      await tap(tester, find.text('已返回，重新检查'));
      expect(find.byType(NativeBusinessDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('iOS grant has no CallLog request', (tester) async {
    await open(tester, 'iOS 直接授权');
    await tap(tester, find.widgetWithText(TextButton, '开启位置权限'));
    expect(find.text('阶段：ready'), findsOneWidget);
    expect(find.textContaining('callLog:'), findsNothing);
    expect(find.textContaining('location:request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'system back cancels location, keeps page and permits ordinary mode',
    (tester) async {
      await open(tester, 'Android 拒绝后去设置');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NativeBusinessDialog), findsNothing);
      expect(find.text('阶段：ready'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.textContaining('location:request'), findsNothing);
      expect(find.textContaining('callLog:request'), findsOneWidget);
    },
  );
}
