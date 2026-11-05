import '../../support/contact_remark_test_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_remark_editor.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_remark_editor_action.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final action in ['entry', 'cancel', 'save', 'input', 'saving']) {
      testWidgets('$platform stale remark $action preserves current draft', (
        tester,
      ) async {
        final directory = _Directory();
        final controller = ContactsController(PreviewContacts(), directory);
        await Future.wait([
          controller.loadDevice(),
          controller.loadDirectory(),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: ContactsRoute()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ContactDetailPage)),
        );
        final entry = tester
            .widget<ContactDetailPage>(find.byType(ContactDetailPage))
            .onEdit;
        await openRetainedRemarkEditor(tester);
        await tester.pumpAndSettle();
        final oldCancel = tester
            .widget<ContactRemarkEditorAction>(
              find.widgetWithText(ContactRemarkEditorAction, '取消'),
            )
            .onPressed;
        final oldSave = tester
            .widget<ContactRemarkEditorAction>(
              find.widgetWithText(ContactRemarkEditorAction, '保存'),
            )
            .onPressed;
        final oldInput = tester
            .widget<TextFormField>(find.byType(TextFormField))
            .onChanged!;
        if (action != 'entry' && action != 'saving') {
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await openRetainedRemarkEditor(tester);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byType(TextFormField),
          'current synthetic draft',
        );
        switch (action) {
          case 'entry':
            entry();
          case 'cancel':
            oldCancel();
          case 'save':
            oldSave();
          case 'input':
            oldInput('stale synthetic draft');
          case 'saving':
            oldSave();
            oldInput('stale synthetic draft');
            oldCancel();
            oldSave();
        }
        await tester.pumpAndSettle();
        expect(find.byType(ContactRemarkEditor), findsOneWidget);
        expect(
          container.read(contactsControllerProvider).draft,
          'current synthetic draft',
        );
        expect(directory.saves, action == 'saving' ? 1 : 0);
        expect(container.read(contactsControllerProvider).editing, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}

class _Directory implements ContactDirectoryRepository {
  int saves = 0;
  final gate = Completer<ContactDirectoryEntry>();
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
