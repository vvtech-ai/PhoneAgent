import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_creation_route.dart';
import 'clone_flow_controller_test.dart' show flow;
import '../commerce/fake_commerce_repository.dart';

class _Creation implements CloneCreationPort {
  bool currentReady = false, reusable = false;
  @override
  Future<List<CloneCreationModel>> models() async => [
    CloneCreationModel(
      cloneEntitled: true,
      currentReady: currentReady,
      pricePoints: 300,
      id: PreviewCloneFlow.model,
      name: '合成模型',
    ),
  ];
  @override
  Future<int> availablePoints() async => 300;
  @override
  Future<bool> hasValidRecording() async => reusable;
}

void main() {
  final epoch = StateProvider<int?>((ref) => 1);
  late ProviderContainer container;
  late PreviewCloneFlow ports;
  late _Creation creation;
  setUp(() {
    ports = PreviewCloneFlow();
    creation = _Creation();
    container = ProviderContainer(
      overrides: [
        commerceRepositoryProvider.overrideWithValue(FakeCommerceRepository()),
        loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
        cloneCreationPortProvider.overrideWithValue(creation),
        cloneFlowProvider.overrideWith(
          (ref, launch) => flow(ports, start: launch.start),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> open(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    String? targetModelId,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    openCloneCreation(context, targetModelId: targetModelId),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final reuse in [true, false]) {
      testWidgets(
        '$platform deleted clone re-entry uses Android flow, reuse=$reuse',
        (tester) async {
          creation.currentReady = true;
          await open(tester, platform: platform);
          expect(find.text('已有克隆音色'), findsOneWidget);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          creation.currentReady = false;
          creation.reusable = reuse;
          await open(
            tester,
            platform: platform,
            targetModelId: PreviewCloneFlow.model,
          );
          expect(find.text('选择声音克隆模型'), findsNothing);
          expect(find.text(reuse ? '声音克隆已完成' : '开始认证'), findsOneWidget);
          expect(ports.capture.prepares, 0);
        },
      );
    }

    testWidgets('$platform known model opens without second selection', (
      tester,
    ) async {
      await open(
        tester,
        platform: platform,
        targetModelId: PreviewCloneFlow.model,
      );
      expect(find.text('开始认证'), findsOneWidget);
      expect(find.text('选择声音克隆模型'), findsNothing);
      expect(ports.capture.prepares, 0);
    });

    testWidgets(
      '$platform unknown creation keeps synchronization without replay',
      (tester) async {
        ports = PreviewCloneFlow(CloneFlowScenario.generationUnknown)
          ..verifiedName = '演练';
        await open(tester, platform: platform);
        await tester.tap(find.text('合成模型'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('clone-consent')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('开始认证'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          '000000200001010005',
        );
        await tester.ensureVisible(find.text('开始人脸跟读认证'));
        await tester.tap(find.text('开始人脸跟读认证'));
        await tester.pumpAndSettle();
        expect(find.text('声音克隆结果待同步，请查询本次结果，勿重复认证'), findsOneWidget);
        expect(find.text('同步本次状态'), findsOneWidget);
        expect(find.textContaining('原生成请求结果未知'), findsNothing);
        expect(ports.candidates.fromVerified, 1);
        expect(ports.candidates.reads, 0);

        expect(find.text('1/3 填写信息'), findsNothing);
        expect(find.text('选择声音克隆模型'), findsNothing);
        await tester.tap(find.text('同步本次状态'));
        await tester.pumpAndSettle();
        expect(ports.candidates.fromVerified, 1);
        expect(ports.candidates.reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancel model picker returns to caller, without initializing SDK',
    (tester) async {
      await open(tester);
      expect(find.text('选择声音克隆模型'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(ports.capture.prepares, 0);
    },
  );
  testWidgets(
    'picker opens the shared production page with no MOCK decoration',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('合成模型'));
      await tester.pumpAndSettle();
      expect(find.text('开始认证'), findsOneWidget);
      expect(find.textContaining('MOCK'), findsNothing);
      expect(ports.capture.prepares, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(ports.closed, isTrue);
    },
  );
  testWidgets(
    'account epoch change removes the active flow and disposes its ports',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('合成模型'));
      await tester.pumpAndSettle();
      container.read(epoch.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(find.text('会话已变化'), findsOneWidget);
      expect(find.text('开始认证'), findsNothing);
      expect(ports.closed, isTrue);
      expect(ports.capture.prepares, 0);
    },
  );
}
