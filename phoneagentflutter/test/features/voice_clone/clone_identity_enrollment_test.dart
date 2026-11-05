import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_confirmation_dialog.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'clone_identity_enrollment_fixture.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_enrollment_steps.dart';

Future<void> press(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform reset cancel, failure, success uses shared dialog at 2x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 720);
        addTearDown(tester.view.reset);
        var deletes = 0;
        final ports = PreviewCloneFlow();
        final controller = identityFlow(
          ports,
          reset: () async {
            if (++deletes == 1) throw StateError('synthetic');
            return true;
          },
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: CloneFlowPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('clone-consent')));
        await tester.pumpAndSettle();
        await press(tester, '开始认证');
        expect(find.text('已认证身份证：000***********0005'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '演***',
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          isEmpty,
        );
        await press(tester, '重置身份');
        expect(find.byType(NativeConfirmationDialog), findsOneWidget);
        expect(find.textContaining('所有克隆音色'), findsOneWidget);
        await press(tester, '取消');
        expect(deletes, 0);
        await press(tester, '重置身份');
        await press(tester, '删除身份及克隆音色');
        expect(deletes, 1);
        expect(controller.state.verifiedName, '演练用户');
        expect(find.text('删除身份失败，请重试'), findsOneWidget);
        await press(tester, '重置身份');
        await press(tester, '删除身份及克隆音色');
        expect(deletes, 2);
        expect(find.text('重置身份'), findsNothing);
        expect(find.byKey(const Key('clone-verified-id-card')), findsNothing);
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(field.controller!.text, isEmpty);
          expect(field.enabled, isTrue);
        }
        expect(ports.capture.prepares, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'editing hides server hint and submits the full newly entered number',
    (tester) async {
      final ports = PreviewCloneFlow();
      final controller = identityFlow(ports);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: CloneFlowPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clone-consent')));
      await tester.pumpAndSettle();
      await press(tester, '开始认证');
      final input = find.byType(TextField).last;
      await tester.ensureVisible(input);
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clone-verified-id-card')), findsNothing);
      await tester.enterText(input, '000000200001010005');
      await press(tester, '开始人脸跟读认证');
      expect(ports.verification.lastIdentity!.number, '000000200001010005');
      expect(ports.verification.lastIdentity!.name, '演练用户');
    },
  );
  testWidgets(
    'failed masked fields clear on keyboard focus; locked names stay masked',
    (tester) async {
      Future<void> show({bool mask = false, String verified = ''}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CloneIdentityStep(
                  busy: false,
                  prefilledName: '合成姓名',
                  verifiedName: verified,
                  maskIdentity: mask,
                  onSubmit: (_, __) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      await tester.enterText(find.byType(TextField).last, '000000200001010005');
      await show(mask: true);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '合***',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '000***********0005',
      );
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      tester
          .widget<TextField>(find.byType(TextField).last)
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await show(verified: '单');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '*',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    },
  );
  test(
    'unverified, empty and unexpectedly unmasked data are not displayed',
    () async {
      for (final entry in [
        (false, '000***********0005'),
        (true, ''),
        (true, '000000200001010005'),
      ]) {
        final controller = identityFlow(
          PreviewCloneFlow(),
          verified: entry.$1,
          masked: entry.$2,
        );
        addTearDown(controller.dispose);
        controller.agree(true);
        await controller.next();
        expect(controller.state.verifiedIdCardMasked, isEmpty);
      }
    },
  );
  test('name limits reject before any verification or capture', () async {
    final ports = PreviewCloneFlow();
    final controller = identityFlow(ports, verified: false);
    addTearDown(controller.dispose);
    controller.agree(true);
    await controller.next();
    for (final name in ['', '单', '名' * 33]) {
      await controller.submitIdentity(name, '000000200001010005');
      expect(controller.state.ui.error, '请输入正确的真实姓名。');
      expect(ports.verification.lastIdentity, isNull);
    }
    await controller.submitIdentity('  演练  ', '000000200001010005');
    expect(ports.verification.lastIdentity!.name, '演练');
  });
  test(
    'pending reset deduplicates and old account completion cannot change state',
    () async {
      var calls = 0;
      final ports = PreviewCloneFlow();
      final pending = Completer<bool>();
      final controller = identityFlow(
        ports,
        reset: () {
          calls++;
          return pending.future;
        },
      );
      addTearDown(controller.dispose);
      controller.agree(true);
      await controller.next();
      final first = controller.resetIdentity();
      await controller.resetIdentity();
      expect(calls, 1);
      ports.current = false;
      pending.complete(true);
      await first;
      expect(controller.state.verifiedName, '演练用户');
    },
  );
  test(
    'cleanup pending clears identity and blocks capture until explicit retry',
    () async {
      var calls = 0;
      final ports = PreviewCloneFlow();
      final controller = identityFlow(ports, reset: () async => ++calls > 1);
      addTearDown(controller.dispose);
      controller.agree(true);
      await controller.next();
      await controller.resetIdentity();
      expect(controller.state.resetCleanupPending, isTrue);
      expect(controller.state.verifiedName, isEmpty);
      await controller.submitIdentity('演练', '000000200001010005');
      expect(ports.capture.prepares, 0);
      await controller.resetIdentity();
      expect(controller.state.resetCleanupPending, isFalse);
      await controller.submitIdentity('演练', '000000200001010005');
      expect(ports.capture.prepares, 1);
    },
  );
}
