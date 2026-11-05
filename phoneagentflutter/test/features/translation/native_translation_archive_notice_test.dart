import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_archive_providers.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/preview_translation_archive.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import '../../../tool/previews/shell_translation_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform pending failure does not add persistent retry UI to native dial flow',
      (tester) async {
        final store = PreviewTranslationArchive()..failArchive = true;
        await store.save([
          TranslationArchiveEntry(
            accountId: 'synthetic',
            clientCallId: 'synthetic',
            targetName: '合成',
            phone: '+12025550123',
            myLanguage: 'zh',
            peerLanguage: 'en',
            locator: const TranslationArchiveLocator(
              'US',
              'synthetic-session',
              'synthetic-grant',
            ),
            connectedAt: 1000,
            endedAt: 2000,
            stage: TranslationArchiveStage.ready,
          ),
        ]);
        final owner = TranslationArchiveController(
          accountId: 'synthetic',
          store: store,
          gateway: store,
          isCurrent: () => true,
        );
        await owner.recover();
        expect(owner.snapshot.failed, true);
        final ports = ShellTranslationPreviewPorts(
          originalAudio: () => const OriginalAudioSettings(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...ports.overrides,
              translationArchiveProvider.overrideWith((ref) => owner),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const TranslationDialerRoute(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('翻译历史同步未完成，点击重试'), findsNothing);
        expect(
          find.byKey(const Key('translation-archive-retry')),
          findsNothing,
        );
        expect(owner.snapshot.failed, true);
        expect((await store.load()), hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        if (owner.mounted) owner.dispose();
      },
    );
  }
}
