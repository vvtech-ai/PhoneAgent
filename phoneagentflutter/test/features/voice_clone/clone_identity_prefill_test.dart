import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';

CloneFlowController _flow(
  PreviewCloneFlow ports,
  Future<CloneIdentityPrefill> Function() read,
) => CloneFlowController(
  CloneCreationLaunch(
    const CloneCreationModel(
      pricePoints: 300,
      id: PreviewCloneFlow.model,
      name: '合成模型',
    ),
    CloneCreationStart.authentication,
  ),
  CloneFlowServices(
    verification: ports.verification,
    candidates: ports.candidates,
    completion: ports,
    capture: () => ports.capture,
    player: ports,
    recordings: CloneFlowRecordings(
      read: ports.readRecording,
      save: ports.save,
      clear: ports.clear,
    ),
    points: () async => ports.points,
    verifiedName: () async => throw StateError('不得额外读取'),
    identityPrefill: read,
    isCurrent: () => ports.current,
  ),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final verified in [false, true]) {
      testWidgets('$platform prefill remains editable only if unverified', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final ports = PreviewCloneFlow();
        var reads = 0;
        final controller = _flow(ports, () async {
          reads++;
          return CloneIdentityPrefill(name: '演练用户', verified: verified);
        });
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
        Future<void> press(Finder target) async {
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await press(find.byKey(const Key('clone-consent')));
        await press(find.text('开始认证'));
        expect(reads, 1);
        final name = find.byType(TextField).first;
        expect(
          tester.widget<TextField>(name).controller!.text,
          verified ? '演***' : '演练用户',
        );
        expect(tester.widget<TextField>(name).enabled, !verified);
        if (!verified) {
          await tester.ensureVisible(name);
          await tester.enterText(name, '修改演练姓名');
        } else {
          await tester.ensureVisible(name);
          await tester.tap(name);
          await tester.pump();
          expect(tester.testTextInput.isVisible, isFalse);
        }
        final number = find.byType(TextField).last;
        await tester.ensureVisible(number);
        await tester.enterText(number, '000000200002300005');
        await press(find.text('开始人脸跟读认证'));
        final error = find.byKey(const ValueKey('clone-flow-error'));
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(
          tester.widget<Text>(error).style!.color,
          const Color(0xFFE14D46),
        );
        expect(
          tester.getTopLeft(error).dy,
          greaterThan(tester.getBottomLeft(number).dy),
        );
        expect(
          tester.widget<TextField>(number).controller!.text,
          '000000200002300005',
        );
        expect(
          tester.widget<TextField>(name).controller!.text,
          verified ? '演***' : '修改演练姓名',
        );
        expect(ports.capture.prepares, 0);
        await tester.ensureVisible(number);
        await tester.enterText(number, '000000200001010005');
        await press(find.text('开始人脸跟读认证'));
        expect(
          ports.verification.lastIdentity!.name,
          verified ? '演练用户' : '修改演练姓名',
        );
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform consent read failure appears once before retry action',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final ports = PreviewCloneFlow();
        var reads = 0;
        final controller = _flow(ports, () async {
          if (++reads == 1) throw StateError('合成读取失败');
          return const CloneIdentityPrefill(name: '重试演练姓名', verified: false);
        });
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
        Future<void> press(Finder target) async {
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await press(find.byKey(const Key('clone-consent')));
        await press(find.text('开始认证'));
        final error = find.byKey(const ValueKey('clone-flow-error'));
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(
          tester.widget<Text>(error).style!.color,
          const Color(0xFFE14D46),
        );
        expect(
          tester.getTopLeft(error).dy,
          greaterThan(
            tester.getBottomLeft(find.byKey(const Key('clone-consent'))).dy,
          ),
        );
        expect(controller.state.ui.agreed, isTrue);
        expect(reads, 1);
        expect(ports.capture.prepares, 0);
        await press(find.text('开始认证'));
        expect(error, findsNothing);
        expect(reads, 2);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '重试演练姓名',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'failed prefill retries one read and empty verified name stays unlocked',
    () async {
      final ports = PreviewCloneFlow();
      var reads = 0;
      final controller = _flow(ports, () async {
        reads++;
        if (reads == 1) throw StateError('合成读取失败');
        return const CloneIdentityPrefill(name: '', verified: true);
      });
      addTearDown(controller.dispose);
      controller.agree(true);
      await controller.next();
      expect(controller.state.ui.step, CloneStep.consent);
      expect(controller.state.ui.error, isNotEmpty);
      await controller.next();
      expect(controller.state.ui.step, CloneStep.identity);
      expect(controller.state.ui.error, isEmpty);
      expect(controller.state.verifiedName, isEmpty);
      expect(controller.state.prefilledName, isEmpty);
      expect(reads, 2);
      expect(ports.capture.prepares, 0);
    },
  );
  test('late prefill from old owner cannot populate identity', () async {
    final ports = PreviewCloneFlow();
    final pending = Completer<CloneIdentityPrefill>();
    final controller = _flow(ports, () => pending.future);
    addTearDown(controller.dispose);
    controller.agree(true);
    final next = controller.next();
    ports.current = false;
    pending.complete(const CloneIdentityPrefill(name: '旧合成姓名', verified: true));
    await next;
    expect(controller.state.prefilledName, isEmpty);
    expect(controller.state.verifiedName, isEmpty);
    expect(controller.state.ui.step, CloneStep.consent);
    expect(ports.capture.prepares, 0);
  });
  test(
    'failed authentication retains current prefill without a new consent read',
    () async {
      final ports = PreviewCloneFlow()..capture.code = 1003;
      var reads = 0;
      final controller = _flow(ports, () async {
        reads++;
        return CloneIdentityPrefill(name: '合成姓名$reads', verified: true);
      });
      addTearDown(controller.dispose);
      controller.agree(true);
      await controller.next();
      await controller.submitIdentity('不可替换锁定', '000000200001010005');
      expect(ports.verification.lastIdentity!.name, '合成姓名1');
      controller.restartAuthentication();
      expect(controller.state.ui.agreed, isTrue);
      expect(controller.state.prefilledName, '合成姓名1');
      expect(controller.state.verifiedName, '合成姓名1');
      await controller.next();
      expect(reads, 1);
      controller.agree(true);
      await controller.next();
      expect(reads, 1);
      expect(controller.state.prefilledName, '合成姓名1');
      expect(controller.state.verifiedName, '合成姓名1');
      expect(ports.candidates.fromVerified, 0);
    },
  );
}
