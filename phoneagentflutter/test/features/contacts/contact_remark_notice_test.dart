import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';

const _notice = '已保存联系人备注';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final outcome in ['accepted', 'failed', 'mismatch', 'released']) {
      testWidgets(
        '$platform remark notice only for accepted current save: $outcome',
        (tester) async {
          final directory = _Directory();
          await _openEditor(tester, directory, platform);
          await tester.enterText(find.byType(TextFormField), '合成备注');
          await tester.tap(find.text('保存'));
          await tester.pump();
          expect(find.text(_notice), findsNothing);
          // The disabled busy control cannot issue another save.
          await tester.tap(find.text('保存中…'));
          await tester.pump();
          expect(directory.saves, 1);
          if (outcome == 'released') {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          }
          if (outcome == 'failed') {
            directory.gate.completeError(StateError('synthetic failure'));
          } else {
            directory.gate.complete(
              ContactDirectoryEntry(
                phone: '2025550101',
                description: outcome == 'mismatch' ? '另一备注' : '合成备注',
              ),
            );
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          if (outcome == 'accepted') {
            expect(find.byType(TextFormField), findsNothing);
            expect(find.text(_notice), findsOneWidget);
            expect(find.text('合成备注'), findsOneWidget);
            // The overlay does not block navigation and expires independently.
            await tester.tap(find.byTooltip('返回联系人'));
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 181));
            await tester.pump(const Duration(milliseconds: 1800));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 181));
            await tester.pump();
            expect(find.text(_notice), findsNothing);
          } else {
            expect(find.text(_notice), findsNothing);
            if (outcome != 'released') {
              expect(find.byType(TextFormField), findsOneWidget);
              expect(find.text('合成备注'), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
    testWidgets('$platform cancelled remark never shows saved notice', (
      tester,
    ) async {
      final directory = _Directory();
      await _openEditor(tester, directory, platform);
      await tester.enterText(find.byType(TextFormField), '取消草稿');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text(_notice), findsNothing);
      expect(find.text('取消草稿'), findsNothing);
      expect(directory.saves, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}

Future<void> _openEditor(
  WidgetTester tester,
  _Directory directory,
  TargetPlatform platform,
) async {
  final controller = ContactsController(PreviewContacts(), directory);
  await Future.wait([controller.loadDevice(), controller.loadDirectory()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [contactsControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const Scaffold(body: ContactsRoute()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

class _Directory implements ContactDirectoryRepository {
  final gate = Completer<ContactDirectoryEntry>();
  int saves = 0;
  @override
  Future<List<ContactDirectoryEntry>> load() async => [];
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) {
    saves++;
    return gate.future;
  }
}
