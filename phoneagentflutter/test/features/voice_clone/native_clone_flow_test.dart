import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_processing_step.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';

CloneFlowController _flow(PreviewCloneFlow ports, {bool reuse = false}) =>
    CloneFlowController(
      CloneCreationLaunch(
        const CloneCreationModel(
          pricePoints: 300,
          id: PreviewCloneFlow.model,
          name: '合成模型',
        ),
        reuse
            ? CloneCreationStart.savedRecording
            : CloneCreationStart.authentication,
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
        verifiedName: () async => ports.verifiedName,
        isCurrent: () => ports.current,
      ),
    );

class _PendingPreview extends PreviewCloneFlow {
  Completer<Uint8List> pending = Completer<Uint8List>();
  @override
  Future<Uint8List> preview(String modelId, {bool current = false}) =>
      pending.future;
}

class _PendingConfirmation extends PreviewCloneFlow {
  final release = Completer<void>();
  @override
  Future<CloneCandidate> confirm(CloneCandidate value) async {
    final result = await super.confirm(value);
    await release.future;
    return result;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform pending confirmation blocks repeated actions at 2x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final ports = _PendingConfirmation();
        final controller = _flow(ports, reuse: true);
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
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => CloneFlowPage(controller: controller),
                    ),
                  ),
                  child: const Text('来源'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('来源'));
        await tester.pumpAndSettle();
        final confirm = find.text('设为默认声音');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('确认中…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(ports.confirms, 1);
        await tester.tap(find.text('确认中…'));
        final rerecord = find.text('重新录制');
        await tester.ensureVisible(rerecord);
        await tester.pump();
        await tester.tap(rerecord);
        final back = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '返回',
        );
        final button = tester.widget<IconButton>(back);
        expect(button.onPressed, isNull);
        await tester.tap(back);
        expect(find.text('确认重新录制？'), findsNothing);
        expect(ports.confirms, 1);
        expect(ports.candidates.fromSaved, 1);
        expect(find.byType(CloneFlowPage), findsOneWidget);
        ports.release.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CloneFlowPage), findsNothing);
        expect(find.text('来源'), findsOneWidget);
        expect(ports.confirms, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'stopped pending preview cannot play late and next preview can start',
    () async {
      final ports = _PendingPreview();
      final controller = _flow(ports, reuse: true);
      addTearDown(controller.dispose);
      await controller.start();
      final first = controller.togglePreview();
      expect(controller.state.ui.previewLoading, isTrue);
      expect(controller.state.ui.playing, isFalse);
      await controller.stopPreview();
      ports.pending.complete(Uint8List.fromList([0]));
      await first;
      expect(ports.plays, 0);
      expect(controller.state.ui.previewLoading, isFalse);
      ports.pending = Completer<Uint8List>();
      final second = controller.togglePreview();
      ports.pending.complete(Uint8List.fromList([0]));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.ui.playing, isTrue);
      expect(controller.state.ui.previewLoading, isFalse);
      await controller.stopPreview();
      await second;
      expect(ports.plays, 1);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final saveFailure in [false, true]) {
      testWidgets(
        '$platform formal clone at 2x returns after confirmation (saveFailure=$saveFailure)',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 640);
          addTearDown(tester.view.reset);
          final ports = PreviewCloneFlow(
            saveFailure
                ? CloneFlowScenario.saveFailure
                : CloneFlowScenario.success,
          )..verifiedName = '合成锁定';
          final controller = _flow(ports);
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => CloneFlowPage(controller: controller),
                      ),
                    ),
                    child: const Text('来源'),
                  ),
                ),
              ),
            ),
          );
          Future<void> press(Finder target) async {
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          await press(find.text('来源'));
          expect(find.textContaining('MOCK'), findsNothing);
          await press(find.byKey(const Key('clone-consent')));
          await press(find.text('开始认证'));
          expect(find.text('1/3 填写信息'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField).first).enabled,
            isFalse,
          );
          await tester.ensureVisible(find.byType(TextField).last);
          await tester.enterText(
            find.byType(TextField).last,
            '000000200001010005',
          );
          await press(find.text('开始人脸跟读认证'));
          expect(find.byKey(const Key('clone-preview')), findsOneWidget);
          await press(find.text('设为默认声音'));
          // Native confirmation closes even if optional recording saving fails.
          expect(find.text('仅重试保存认证录音'), findsNothing);
          expect(find.byType(CloneFlowPage), findsNothing);
          expect(find.text('来源'), findsOneWidget);
          expect(ports.confirms, 1);
          expect(ports.saves, 1);
          expect(ports.restores, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform verification sync error appears once at $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        final ports = PreviewCloneFlow(CloneFlowScenario.verificationSync)
          ..verifiedName = '合成锁定';
        final controller = _flow(ports);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
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
        final number = find.byType(TextField).last;
        await tester.ensureVisible(number);
        await tester.enterText(number, '000000200001010005');
        await press(find.text('开始人脸跟读认证'));
        final message = controller.state.ui.error;
        expect(message, isNotEmpty);
        final error = find.byKey(const ValueKey('clone-flow-error'));
        await tester.scrollUntilVisible(
          error,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(error, findsOneWidget);
        expect(
          find.ancestor(of: error, matching: find.byType(CloneProcessingStep)),
          findsOneWidget,
        );
        expect(ports.verification.initializes, 1);
        expect(ports.capture.captures, 1);
        expect(ports.verification.reads, 1);
        expect(ports.candidates.fromVerified, 0);
        await tester.scrollUntilVisible(
          find.text('同步本次状态'),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await press(find.text('同步本次状态'));
        expect(find.byKey(const ValueKey('clone-flow-error')), findsNothing);
        expect(ports.verification.initializes, 1);
        expect(ports.capture.captures, 1);
        expect(ports.verification.reads, 2);
        expect(ports.candidates.fromVerified, 1);
        expect(ports.confirms, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
