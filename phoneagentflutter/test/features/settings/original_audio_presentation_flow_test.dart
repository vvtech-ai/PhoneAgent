import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';

class _DelayedStore implements OriginalAudioStore {
  final loaded = Completer<OriginalAudioSettings>();
  final saved = Completer<void>();
  var writes = 0;
  OriginalAudioSettings? last;
  @override
  Future<OriginalAudioSettings> read() => loaded.future;
  @override
  Future<void> write(OriginalAudioSettings value) {
    writes++;
    last = value;
    return writes == 1 ? saved.future : Future.value();
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform original audio status and explicit save retry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = _DelayedStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [originalAudioStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const OriginalAudioPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(NativePageBackground), findsOneWidget);
      expect(tester.getRect(find.byType(NativePageBackground)).top, 0);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(store.writes, 0);
      store.loaded.complete(const OriginalAudioSettings(enabled: true));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('已保存在当前设备'), findsNothing);
      await tester.tap(find.byKey(const Key('original-enabled')));
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(store.last!.enabled, isFalse);
      expect(store.last!.gain, 50);
      expect(store.last!.volume, 100);
      expect(
        tester
            .widget<Slider>(find.byKey(const Key('original-volume')))
            .onChanged,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('保存中…'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('保存中…'), findsOneWidget);
      store.saved.completeError(StateError('synthetic save failed'));
      await tester.pumpAndSettle();
      expect(find.text('保存中…'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('original-error')),
        -120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('设置尚未保存，请重试'), findsOneWidget);
      await tester.ensureVisible(find.text('重试保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试保存'));
      await tester.pumpAndSettle();
      expect(store.writes, 2);
      expect(find.text('设置尚未保存，请重试'), findsNothing);
      expect(find.text('已保存在当前设备'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
