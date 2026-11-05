import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/domestic_translation_quality_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/domain/translation_model_quality.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_option.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_model_panel.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_latency_pill.dart';
import 'support/domestic_model_sheet_fixture.dart';

class _Pending implements TranslationModelProbe {
  final models = <String>[];
  final pending = <Completer<TranslationModelSample>>[];
  @override
  Future<TranslationModelSample> sample(String model) {
    models.add(model);
    final gate = Completer<TranslationModelSample>();
    pending.add(gate);
    return gate.future;
  }
}

final _epoch = StateProvider<int>((_) => 1);

void main() {
  test('domestic quality rejects late region/account samples', () async {
    final probe = _Pending();
    final container = ProviderContainer(
      overrides: [
        translationDirectoryProvider.overrideWith(
          (ref) async => syntheticTranslationDirectory,
        ),
        loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
        translationAccessProvider.overrideWith((ref) => ref.watch(sheetAccess)),
        domesticTranslationModelProbeProvider.overrideWithValue(probe),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      domesticTranslationModelQualityProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(probe.models, ['QWEN_OMNI_PLUS', 'DOUBAO']);
    container.read(sheetAccess.notifier).state = const TranslationAccess(
      countryIso: 'US',
      forced: false,
    );
    expect(
      await container.read(domesticTranslationModelQualityProvider.future),
      isEmpty,
    );
    probe.pending[0].complete(TranslationModelSample.reachable(20));
    probe.pending[1].complete(TranslationModelSample.reachable(21));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(domesticTranslationModelQualityProvider).value,
      isEmpty,
    );
    container.read(sheetAccess.notifier).state = const TranslationAccess(
      countryIso: 'CN',
      forced: false,
    );
    container.read(domesticTranslationModelQualityProvider);
    container.read(_epoch.notifier).state++;
    final future = container.read(
      domesticTranslationModelQualityProvider.future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(probe.pending, hasLength(6));
    probe.pending[4].complete(TranslationModelSample.reachable(700));
    probe.pending[5].completeError(StateError('synthetic failure'));
    final samples = await future;
    expect(samples['QWEN_OMNI_PLUS']!.latencyMs, 700);
    expect(samples['DOUBAO']!.quality, TranslationQuality.unavailable);
    probe.pending[2].complete(TranslationModelSample.reachable(1));
    probe.pending[3].complete(TranslationModelSample.reachable(2));
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(domesticTranslationModelQualityProvider)
          .value!['QWEN_OMNI_PLUS']!
          .latencyMs,
      700,
    );
  });
  for (final access in [
    const TranslationAccess(countryIso: null, forced: false),
    const TranslationAccess(countryIso: 'CN', forced: false, loading: true),
    const TranslationAccess(countryIso: 'CN', forced: true),
  ]) {
    test(
      'no domestic requests for ${access.countryIso}/${access.loading}/${access.forced}',
      () async {
        final probe = _Pending();
        final container = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            translationAccessProvider.overrideWithValue(access),
            domesticTranslationModelProbeProvider.overrideWithValue(probe),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(domesticTranslationModelQualityProvider.future),
          isEmpty,
        );
        expect(probe.models, isEmpty);
      },
    );
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('domestic refresh drives all pill states $platform', (
      tester,
    ) async {
      final probe = _Pending();
      await mountSheetDialer(
        tester,
        SheetRepository(),
        probe: probe,
        platform: platform,
      );
      await tester.tap(find.byKey(const ValueKey('translation-model-open')));
      await tester.pump(const Duration(milliseconds: 400));
      NativeTranslationModelOption row(String id) =>
          tester.widget(find.byKey(ValueKey('domestic-model-$id')));
      Color? pillColor(String id) {
        final pill = find.descendant(
          of: find.byKey(ValueKey('domestic-model-$id')),
          matching: find.byType(TranslationLatencyPill),
        );
        final box = find.descendant(of: pill, matching: find.byType(Container));
        return (tester.widget<Container>(box).decoration as BoxDecoration)
            .color;
      }

      expect(row('QWEN_OMNI_PLUS').sample, isNull);
      expect(pillColor('QWEN_OMNI_PLUS'), const Color(0xFFD1D5DB));
      expect(pillColor('OPENAI'), const Color(0xFFFF3B30));
      expect(row('OPENAI').sample!.quality, TranslationQuality.unavailable);
      probe.pending[0].complete(TranslationModelSample.reachable(140));
      probe.pending[1].complete(TranslationModelSample.reachable(350));
      await tester.pumpAndSettle();
      expect(find.text('140ms'), findsOneWidget);
      expect(find.text('350ms'), findsOneWidget);
      expect(pillColor('QWEN_OMNI_PLUS'), const Color(0xFF34C759));
      expect(pillColor('DOUBAO'), const Color(0xFFFFCC00));
      expect(find.text('不可用'), findsNWidgets(2));
      final panel = tester.widget<NativeTranslationModelPanel>(
        find.byType(NativeTranslationModelPanel),
      );
      panel.onRefresh!();
      await tester.pump();
      await tester.pump();
      expect(probe.models, [
        'QWEN_OMNI_PLUS',
        'DOUBAO',
        'QWEN_OMNI_PLUS',
        'DOUBAO',
      ]);
      expect(row('QWEN_OMNI_PLUS').sample!.latencyMs, 140);
      expect(row('QWEN_OMNI_PLUS').selected, isTrue);
      expect(
        tester
            .widget<NativeTranslationModelPanel>(
              find.byType(NativeTranslationModelPanel),
            )
            .onRefresh,
        isNull,
      );
      probe.pending[2].complete(TranslationModelSample.reachable(700));
      probe.pending[3].completeError(StateError('synthetic network failure'));
      await tester.pumpAndSettle();
      expect(find.text('700ms'), findsOneWidget);
      expect(find.text('不可用'), findsNWidgets(3));
      final pill = find.descendant(
        of: find.byKey(const ValueKey('domestic-model-QWEN_OMNI_PLUS')),
        matching: find.byType(TranslationLatencyPill),
      );
      final box = find.descendant(of: pill, matching: find.byType(Container));
      expect(
        (tester.widget<Container>(box).decoration as BoxDecoration).color,
        const Color(0xFFFF9500),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
