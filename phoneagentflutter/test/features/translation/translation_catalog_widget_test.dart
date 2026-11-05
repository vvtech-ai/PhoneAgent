import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_catalog_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_catalog_status.dart';

class _Repository implements TranslationCatalogRepository {
  final reads = <(String, Completer<TranslationServiceCatalog>)>[];
  @override
  Future<TranslationServiceCatalog> load(String region) {
    final gate = Completer<TranslationServiceCatalog>();
    reads.add((region, gate));
    return gate.future;
  }
}

const _us = TranslationServiceCatalog([
  TranslationServiceLanguage('en-US', 'English'),
]);
const _jp = TranslationServiceCatalog([
  TranslationServiceLanguage('ja-JP', 'Japanese'),
]);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<_Repository> openFailed(WidgetTester tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationCatalogRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: TranslationCatalogStatus(region: 'US'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      repository.reads.single.$2.completeError(
        TranslationCatalogFailure.network,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return repository;
    }

    testWidgets('covered catalog retry is inert on $platform', (tester) async {
      final repository = await openFailed(tester);
      final retry = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '重试读取语言目录'))
          .onPressed!;
      Navigator.of(
        tester.element(find.byType(TranslationCatalogStatus)),
      ).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('covered')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      retry();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.reads, hasLength(1));
      expect(find.text('covered'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'old regional retry cannot invalidate retained previous region on $platform',
      (tester) async {
        final repository = _Repository();
        var region = 'US';
        late StateSetter update;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationCatalogRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Scaffold(
                    body: TranslationCatalogStatus(region: region),
                  );
                },
              ),
            ),
          ),
        );
        repository.reads.single.$2.completeError(
          TranslationCatalogFailure.network,
        );
        await tester.pump();
        final retry = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '重试读取语言目录'))
            .onPressed!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TranslationCatalogStatus)),
        );
        final retained = container.listen(
          translationCatalogProvider('US'),
          (_, __) {},
        );
        addTearDown(retained.close);
        update(() => region = 'JP');
        await tester.pump();
        expect(repository.reads.map((item) => item.$1), ['US', 'JP']);
        retry();
        await tester.pump();
        expect(repository.reads.map((item) => item.$1), ['US', 'JP']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'disposed catalog retry cannot affect reopened page on $platform',
      (tester) async {
        final repository = await openFailed(tester);
        final retry = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '重试读取语言目录'))
            .onPressed!;
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final currentReads = repository.reads.length;
        retry();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(repository.reads, hasLength(currentReads));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'region late responses cannot replace current catalog, retry and empty',
    (tester) async {
      final repository = _Repository();
      final controller = TranslationSetupController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationCatalogRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: TranslationSettingsPage(
              controller: controller,
              serviceStatusBuilder: (region) =>
                  TranslationCatalogStatus(region: region),
            ),
          ),
        ),
      );
      expect(repository.reads.single.$1, 'DEFAULT');
      expect(find.text('正在读取所选节点支持的语言…'), findsOneWidget);
      controller.region('JP');
      await tester.pump();
      expect(repository.reads.last.$1, 'JP');
      repository.reads.last.$2.complete(_jp);
      await tester.pump();
      expect(find.text('Japanese'), findsOneWidget);
      repository.reads.first.$2.complete(_us);
      await tester.pump();
      expect(find.text('English'), findsNothing);
      expect(find.text('Japanese'), findsOneWidget);
      controller.region('US');
      await tester.pump();
      repository.reads.last.$2.completeError(TranslationCatalogFailure.network);
      await tester.pump();
      expect(find.text('重试读取语言目录'), findsOneWidget);
      final retry = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '重试读取语言目录'))
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(repository.reads, hasLength(4));
      repository.reads.last.$2.complete(const TranslationServiceCatalog([]));
      await tester.pump();
      await tester.pump();
      expect(repository.reads, hasLength(4));
      expect(find.text('此节点未返回支持语言'), findsOneWidget);
      expect(controller.snapshot.provider, 'GEMINI');
      expect(controller.snapshot.caller, 'zh');
      expect(controller.snapshot.peer, 'en');
    },
  );

  testWidgets(
    'isolated settings without status builder never query real service',
    (tester) async {
      final repository = _Repository();
      final controller = TranslationSetupController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationCatalogRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: TranslationSettingsPage(controller: controller),
          ),
        ),
      );
      controller.region('JP');
      await tester.pump();
      expect(repository.reads, isEmpty);
    },
  );
}
