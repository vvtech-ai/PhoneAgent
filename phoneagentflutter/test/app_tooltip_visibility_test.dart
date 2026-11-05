import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/core/design/native_detail_header.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_identity_display_port.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_overlay_app.dart';

import 'support/pump_ui_transitions.dart';

void main() {
  for (final overlay in [false, true]) {
    testWidgets(
      '${overlay ? 'identity overlay' : 'main app'} suppresses button tooltips across routes and sheets',
      (tester) async {
        const channel = MethodChannel('phone_agent/trusted_identity_overlay');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          overlay
              ? TrustedIdentityOverlayApp(
                  port: DeviceTrustedIdentityDisplayPort(),
                )
              : const ProviderScope(child: PhoneAgentApp()),
        );
        await tester.pumpUntilUiSettled();
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        var presses = 0;
        navigator.push<void>(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  NativeDetailHeader(
                    title: '测试页面',
                    onBack: () => navigator.pop(),
                  ),
                  IconButton(
                    tooltip: '关闭测试控件',
                    onPressed: () => presses++,
                    icon: const Icon(Icons.close),
                  ),
                  Tooltip(
                    message: '测试操作提示',
                    child: TextButton(
                      onPressed: () => presses++,
                      child: const Text('测试操作'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (context) => IconButton(
                        tooltip: '关闭测试弹层',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    child: const Text('打开弹层'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        Future<void> expectHidden(String message) async {
          final tooltip = find.byTooltip(message);
          expect(tooltip, findsOneWidget);
          final gesture = await tester.startGesture(tester.getCenter(tooltip));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text(message), findsNothing);
          expect(
            tester.state<TooltipState>(tooltip).ensureTooltipVisible(),
            isFalse,
          );
          await gesture.cancel();
          await tester.pump();
        }

        await expectHidden('返回');
        expect(find.text('测试页面'), findsOneWidget);
        await expectHidden('关闭测试控件');
        final close = find.widgetWithIcon(IconButton, Icons.close);
        expect(tester.getSemantics(close).getSemanticsData().tooltip, '关闭测试控件');
        await tester.tap(close);
        expect(presses, 1);
        await expectHidden('测试操作提示');
        await tester.tap(find.text('测试操作'));
        expect(presses, 2);
        await tester.tap(find.text('打开弹层'));
        await tester.pumpUntilUiSettled();
        await expectHidden('关闭测试弹层');
        await tester.tap(find.byTooltip('关闭测试弹层'));
        await tester.pumpUntilUiSettled();
        expect(find.byTooltip('关闭测试弹层'), findsNothing);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpUntilUiSettled();
        expect(find.text('测试页面'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpUntilUiSettled();
        semantics.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
