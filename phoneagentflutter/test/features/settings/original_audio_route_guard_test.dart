import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';

class _Store implements OriginalAudioStore {
  var writes = 0;
  @override
  Future<OriginalAudioSettings> read() async =>
      const OriginalAudioSettings(enabled: true);
  @override
  Future<void> write(OriginalAudioSettings value) async {
    writes++;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform old audio page cannot write behind cover or after disposal',
      (tester) async {
        final store = _Store();
        final container = ProviderContainer(
          overrides: [originalAudioStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: ThemeData(platform: platform),
              home: const OriginalAudioPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final back = tester
            .widget<NativePageHeader>(find.byType(NativePageHeader))
            .onBack!;
        final toggle = tester
            .widget<NativeAudioToggle>(find.byType(NativeAudioToggle))
            .onChanged!;
        final volume = tester
            .widget<NativeAudioLevel>(find.byType(NativeAudioLevel).first)
            .onChanged!;
        final gain = tester
            .widget<NativeAudioLevel>(find.byType(NativeAudioLevel).last)
            .onChanged!;
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('cover')),
        );
        await tester.pumpAndSettle();
        back();
        await tester.pumpAndSettle();
        expect(find.text('cover'), findsOneWidget);
        toggle(false);
        volume(40);
        gain(20);
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        expect(
          container.read(originalAudioControllerProvider).value.enabled,
          isTrue,
        );
        await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
        await tester.pumpAndSettle();
        back();
        toggle(false);
        volume(40);
        gain(20);
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$platform stale slider respects latest disabled preference', (
      tester,
    ) async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [originalAudioStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const OriginalAudioPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final volume = tester
          .widget<NativeAudioLevel>(find.byType(NativeAudioLevel).first)
          .onChanged!;
      final controller = container.read(
        originalAudioControllerProvider.notifier,
      );
      controller.change(enabled: false);
      volume(40);
      expect(container.read(originalAudioControllerProvider).value.volume, 100);
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
