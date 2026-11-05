import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/data/preview_documents.dart';
import 'package:phone_agent/features/attachments/presentation/controller/document_import_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/document_import_sheet.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_model_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      for (final document in [false, true]) {
        testWidgets(
          '$platform independent close document=$document large=$large',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            if (large) {
              tester.platformDispatcher.textScaleFactorTestValue = 2;
            }
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();
            final setup = TranslationSetupController();
            try {
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp(
                    home: Builder(
                      builder: (root) => Scaffold(
                        body: TextButton(
                          child: const Text('打开'),
                          onPressed: () {
                            if (!document) {
                              showTranslationModelSheet(
                                root,
                                setup,
                                preview: true,
                              );
                              return;
                            }
                            final port = PreviewDocuments(
                              DocumentPreviewScenario.success,
                            );
                            showModalBottomSheet<void>(
                              context: root,
                              isScrollControlled: true,
                              builder: (_) => DocumentImportSheet(
                                controller: DocumentImportController(
                                  port,
                                  port,
                                  () => 'synthetic',
                                ),
                                onReady: (_) => true,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final label = document ? '关闭文档导入' : '关闭';
              await tester.tap(find.text('打开'));
              await tester.pumpAndSettle();
              final action = find.byTooltip(label);
              final node = tester.getSemantics(action);
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isImage), isFalse);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(
                tester.getSize(action),
                document ? const Size(48, 48) : const Size(44, 44),
              );
              final icon = find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == label,
              );
              final old = tester.widget<IconButton>(icon).onPressed!;
              final sheetContext = tester.element(icon);
              Navigator.of(sheetContext).push<void>(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('合成覆盖页')),
                ),
              );
              await tester.pumpAndSettle();
              old();
              await tester.pumpAndSettle();
              expect(find.text('合成覆盖页'), findsOneWidget);
              Navigator.of(sheetContext).pop();
              await tester.pumpAndSettle();
              old();
              old();
              await tester.pumpAndSettle();
              expect(find.text('打开'), findsOneWidget);
              expect(action, findsNothing);
              await tester.tap(find.text('打开'));
              await tester.pumpAndSettle();
              old();
              await tester.pumpAndSettle();
              expect(action, findsOneWidget);
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(action, findsNothing);
              expect(find.text('打开'), findsOneWidget);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              setup.dispose();
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }
}
