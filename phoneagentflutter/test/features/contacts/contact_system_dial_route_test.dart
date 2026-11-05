import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/dialer_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';

class _PendingDialer implements SystemDialer {
  final pending = Completer<SystemDialResult>();
  final targets = <String>[];

  @override
  Future<SystemDialResult> open(String number) {
    targets.add(number);
    return pending.future;
  }
}

void main() {
  for (final leave in [false, true]) {
    testWidgets('contact handoff busy and late feedback leave=$leave', (
      tester,
    ) async {
      final device = PreviewContacts();
      final contacts = ContactsController(device, device.directory);
      await Future.wait([contacts.loadDevice(), contacts.loadDirectory()]);
      final dialer = _PendingDialer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactsSharedFlowEnabledProvider.overrideWithValue(true),
            contactsControllerProvider.overrideWith((ref) => contacts),
            systemDialerProvider.overrideWithValue(dialer),
          ],
          child: const MaterialApp(home: Scaffold(body: ContactsRoute())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拨打电话'));
      await tester.pump();
      expect(
        tester
            .widget<ContactDetailPage>(find.byType(ContactDetailPage))
            .dialBusy,
        isTrue,
      );
      await tester.tap(find.text('拨打电话'));
      await tester.pump();
      expect(dialer.targets, ['2025550101']);
      expect(find.byKey(const ValueKey('dial-country')), findsNothing);
      if (leave) {
        await tester.tap(find.byTooltip('返回联系人'));
        await tester.pumpAndSettle();
      }
      dialer.pending.complete(SystemDialResult.failed);
      await tester.pumpAndSettle();
      expect(
        find.text('无法打开系统拨号盘，请稍后重试'),
        leave ? findsNothing : findsOneWidget,
      );
      if (!leave) {
        expect(
          tester
              .widget<ContactDetailPage>(find.byType(ContactDetailPage))
              .dialBusy,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
