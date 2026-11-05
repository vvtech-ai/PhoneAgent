import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_remark_editor.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform remark name, semantic editing and busy guard', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final directory = _PendingDirectory();
        final controller = ContactsController(PreviewContacts(), directory);
        await controller.loadDirectory();
        controller.openDetail(
          const ContactRecord(
            name: '合成联系人',
            phone: '2025550101',
            systemDialPhone: '2025550101',
          ),
        );
        controller.beginEdit();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsControllerProvider.overrideWith((_) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: ContactRemarkEditor()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        SemanticsNode field() {
          final found = <SemanticsNode>[];
          void visit(SemanticsNode node) {
            if (node.hasFlag(SemanticsFlag.isTextField) &&
                node.label.contains('联系人备注')) {
              found.add(node);
            }
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester
                .binding
                .renderViews
                .single
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          expect(found, hasLength(1));
          return found.single;
        }

        expect(field().value, '合成原备注');
        await tester.tap(find.byType(TextFormField));
        await tester.pumpAndSettle();
        expect(field().hasFlag(SemanticsFlag.isFocused), true);
        expect(
          field().getSemanticsData().hasAction(SemanticsAction.setText),
          true,
        );
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          field().id,
          SemanticsAction.setText,
          '合成修改备注',
        );
        await tester.pumpAndSettle();
        expect(field().value, '合成修改备注');
        expect(find.text('6/2000'), findsOneWidget);
        await tester.tap(find.text('保存'));
        await tester.pump();
        expect(directory.submitted, '合成修改备注');
        expect(directory.saves, 1);
        expect(
          field().getSemanticsData().hasAction(SemanticsAction.setText),
          false,
        );
        expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
          false,
        );
        await tester.tap(find.text('保存中…'));
        await tester.pump();
        expect(directory.saves, 1);
        await tester.pumpWidget(const SizedBox());
        directory.gate.completeError(StateError('合成失败'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}

class _PendingDirectory implements ContactDirectoryRepository {
  final gate = Completer<ContactDirectoryEntry>();
  int saves = 0;
  String? submitted;
  @override
  Future<List<ContactDirectoryEntry>> load() async => [
    const ContactDirectoryEntry(phone: '2025550101', description: '合成原备注'),
  ];
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) {
    saves++;
    submitted = remark;
    return gate.future;
  }
}
