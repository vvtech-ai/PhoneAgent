import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('list/detail/edit/cancel/save/back at $width', (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = PreviewContacts();
      final c = ContactsController(device, device.directory);
      await Future.wait([c.loadDevice(), c.loadDirectory()]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [contactsControllerProvider.overrideWith((ref) => c)],
          child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('演示联系人'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactDetailPage), findsOneWidget);
      expect(find.byTooltip('返回联系人'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '未保存的备注');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('未保存的备注'), findsNothing);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), ' 新备注 ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('新备注'), findsOneWidget);
      await tester.tap(find.byTooltip('返回联系人'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('演示联系人，2025550102'), findsOneWidget);
      expect(c.state.selected, isNull);
      await tester.tap(find.bySemanticsLabel('演示联系人，2025550102'));
      await tester.pumpAndSettle();
      expect(find.text('暂无备注'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remark backdrop discards unsaved draft without saving', (
    tester,
  ) async {
    final directory = _Directory();
    final c = ContactsController(PreviewContacts(), directory);
    await Future.wait([c.loadDevice(), c.loadDirectory()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contactsControllerProvider.overrideWith((ref) => c)],
        child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '草稿');
    await tester.pump();
    expect(find.text('2/2000'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('编辑备注'), findsNothing);
    expect(c.state.editing, isFalse);
    expect(c.state.draft, isEmpty);
    expect(directory.saves, 0);
    expect(find.byType(ContactDetailPage), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('草稿'), findsNothing);
    expect(find.text('编辑备注'), findsOneWidget);
  });

  testWidgets('failed save retains draft; busy back is blocked; retry works', (
    tester,
  ) async {
    final directory = _Directory();
    final c = ContactsController(PreviewContacts(), directory);
    await Future.wait([c.loadDevice(), c.loadDirectory()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contactsControllerProvider.overrideWith((ref) => c)],
        child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '保留草稿');
    directory.gate = Completer<ContactDirectoryEntry>();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('编辑备注'), findsOneWidget);
    expect(directory.saves, 1);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('编辑备注'), findsOneWidget);
    directory.gate!.completeError(StateError('synthetic failure'));
    await tester.pumpAndSettle();
    expect(find.text('保存联系人备注失败，请重试'), findsOneWidget);
    expect(find.text('保留草稿'), findsOneWidget);
    directory.gate = null;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('保留草稿'), findsOneWidget);
    expect(directory.saves, 2);
  });

  for (final access in [
    ContactAccess.notDetermined,
    ContactAccess.denied,
    ContactAccess.restricted,
    ContactAccess.limited,
    ContactAccess.unsupported,
    ContactAccess.authorized,
  ]) {
    testWidgets('permission/empty state $access never fabricates contacts', (
      tester,
    ) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactsPage(
              state: ContactsState(access: access),
              onOpen: (_) => fail('no rows'),
              onRefresh: () async {},
              onRequestPermission: () => requests++,
            ),
          ),
        ),
      );
      expect(find.text('演示联系人'), findsNothing);
      if (access == ContactAccess.notDetermined ||
          access == ContactAccess.denied) {
        await tester.tap(find.byType(TextButton).first);
        expect(requests, 1);
      } else {
        expect(requests, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remark editor scrolls with keyboard and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final device = PreviewContacts();
    final c = ContactsController(device, device.directory);
    await Future.wait([c.loadDevice(), c.loadDirectory()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contactsControllerProvider.overrideWith((ref) => c)],
        child: MaterialApp(
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
    await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('编辑'),
      100,
      scrollable: find.descendant(
        of: find.byType(ContactDetailPage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '键盘备注');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(c.state.remark, '键盘备注');
  });
}

class _Directory implements ContactDirectoryRepository {
  Completer<ContactDirectoryEntry>? gate;
  int saves = 0;
  @override
  Future<List<ContactDirectoryEntry>> load() async => [];
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async {
    saves++;
    return gate?.future ??
        ContactDirectoryEntry(phone: contact.phone, description: remark);
  }
}
