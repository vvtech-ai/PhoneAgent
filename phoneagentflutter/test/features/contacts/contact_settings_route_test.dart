import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';

class _Device implements DeviceContactSource {
  ContactAccess access = ContactAccess.denied;
  final requests = <bool>[];
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    requests.add(requestPermission);
    return DeviceContactsSnapshot(access, const [
      DeviceContactRow(name: '合成联系人', phone: '2025550101'),
    ]);
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform settings single flight and foreground silent reread',
      (tester) async {
        final source = _Device();
        final c = ContactsController(source, PreviewContacts().directory);
        await c.loadDevice();
        var opened = 0;
        final gate = Completer<void>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsSharedFlowEnabledProvider.overrideWithValue(true),
              contactsControllerProvider.overrideWith((ref) => c),
              contactSettingsLauncherProvider.overrideWithValue(() {
                opened++;
                return gate.future;
              }),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: ContactsRoute()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final oldPage = tester.widget<ContactsPage>(find.byType(ContactsPage));
        await tester.tap(find.text('去设置授权'));
        await tester.tap(find.text('去设置授权'));
        expect(opened, 1);
        source.access = ContactAccess.limited;
        gate.complete();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(source.requests, [false, false, false]);
        expect(find.text('仅显示已授权的联系人'), findsOneWidget);
        expect(find.bySemanticsLabel('合成联系人，2025550101'), findsOneWidget);
        final navigator = Navigator.of(
          tester.element(find.byType(ContactsRoute)),
        );
        navigator.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('覆盖页'))),
        );
        await tester.pumpAndSettle();
        oldPage.onRequestPermission();
        oldPage.onSettings!();
        await oldPage.onRefresh();
        await tester.pumpAndSettle();
        expect(source.requests, [false, false, false]);
        expect(opened, 1);
        expect(find.text('覆盖页'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
