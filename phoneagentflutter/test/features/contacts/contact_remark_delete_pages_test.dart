import '../../support/contact_remark_test_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/core/design/native_confirmation_dialog.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';

Future<void> press(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Failure
    implements ContactDirectoryRepository, ContactDirectoryDeletionPort {
  var deletes = 0;
  @override
  Future<List<ContactDirectoryEntry>> load() async => [
    const ContactDirectoryEntry(phone: '2025550101', description: '保留备注'),
  ];
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteRemark(String phoneKey) async {
    deletes++;
    throw StateError('synthetic');
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform remark cancel then repeated confirmation deletes only AI entry at 2x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        final source = PreviewContacts();
        final controller = ContactsController(source, source.directory);
        await controller.loadDevice();
        await controller.loadDirectory();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: ContactsRoute()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await press(tester, find.bySemanticsLabel('演示联系人，2025550101'));
        expect(
          find.byKey(const ValueKey('contact-remark-delete')),
          findsNothing,
        );
        await openRetainedRemarkEditor(tester);
        await tester.enterText(
          find.byKey(const ValueKey('contact-remark-input')),
          'ui-remark',
        );
        await press(tester, find.text('保存'));
        await requestRetainedRemarkDeletion(tester);
        expect(find.text('本机通讯录联系人不会被删除。'), findsOneWidget);
        await press(tester, find.text('取消'));
        expect(controller.state.remark, 'ui-remark');
        expect(find.byType(ContactDetailPage), findsOneWidget);
        await requestRetainedRemarkDeletion(tester);
        final confirm = find.descendant(
          of: find.byType(NativeConfirmationDialog),
          matching: find.widgetWithText(TextButton, '删除'),
        );
        final callback = tester.widget<TextButton>(confirm).onPressed!;
        callback();
        callback();
        await tester.pumpAndSettle();
        expect(controller.state.directory, isEmpty);
        expect(controller.state.contacts.length, 3);
        expect(find.byType(ContactDetailPage), findsNothing);
        await press(tester, find.bySemanticsLabel('演示联系人，2025550101'));
        expect(
          find.byKey(const ValueKey('contact-remark-delete')),
          findsNothing,
        );
        expect(controller.state.remark, isEmpty);
        expect(find.text('暂无备注'), findsNothing);
        expect(
          find.byKey(const ValueKey('contact-remark-delete')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('delete failure alerts and keeps original detail without retry', (
    tester,
  ) async {
    final port = _Failure();
    final controller = ContactsController(PreviewContacts(), port);
    await controller.loadDevice();
    await controller.loadDirectory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactsControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, find.bySemanticsLabel('演示联系人，2025550101'));
    await requestRetainedRemarkDeletion(tester);
    await press(
      tester,
      find.descendant(
        of: find.byType(NativeConfirmationDialog),
        matching: find.widgetWithText(TextButton, '删除'),
      ),
    );
    expect(find.text('删除失败'), findsOneWidget);
    expect(port.deletes, 1);
    await press(tester, find.text('确定'));
    expect(find.byType(ContactDetailPage), findsOneWidget);
    expect(controller.state.remark, '保留备注');
    expect(find.text('保留备注'), findsNothing);
    expect(port.deletes, 1);
    expect(tester.takeException(), isNull);
  });
}
