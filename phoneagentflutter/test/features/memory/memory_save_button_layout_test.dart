import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_editor_page.dart';
import 'memory_pages_test.dart' show Repository;

void expectSingleLine(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: label.length),
  );
  expect(boxes, isNotEmpty);
  expect(boxes.map((box) => box.top).toSet(), hasLength(1));
  final button = tester.getRect(find.byType(FilledButton));
  for (final box in boxes) {
    final global = paragraph.localToGlobal(Offset(box.left, box.top));
    expect(global.dy, greaterThanOrEqualTo(button.top - .1));
    expect(
      global.dy + box.bottom - box.top,
      lessThanOrEqualTo(button.bottom + .1),
    );
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.1));
    expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.1));
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final editing in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$platform ${editing ? 'edit' : 'add'} save label fits native button scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final repo = Repository();
            final original = MemoryEntry(
              id: 'synthetic',
              content: '原记忆',
              scope: MemoryScope.all,
              skillIds: [],
            );
            if (editing) repo.entries.add(original);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  loginEpochProvider.overrideWithValue(7),
                  memoryRepositoryProvider.overrideWithValue(repo),
                ],
                child: MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: MemoryEditorPage(entry: editing ? original : null),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final button = find.byType(FilledButton);
            expect(tester.widget<FilledButton>(button).onPressed, isNull);
            expectSingleLine(tester, '保存');
            await tester.enterText(find.byType(TextField), '新记忆');
            if (!editing) {
              await tester.tap(find.text('选择适用任务'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('全部任务'));
              await tester.tap(find.text('完成'));
              await tester.pumpAndSettle();
            }
            await tester.pump();
            expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
            expectSingleLine(tester, '保存');
            repo.pending = Completer<void>();
            await tester.tap(button);
            await tester.pump();
            expect(tester.widget<FilledButton>(button).onPressed, isNull);
            expectSingleLine(tester, '保存中');
            expect(tester.getSize(button).height, 38);
            expect(tester.takeException(), isNull);
            repo.pending!.complete();
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
