import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/contact_entry_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_authorization.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_tab_entry_gate.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';

final _epoch = StateProvider<int>((ref) => 0);

class _Port implements ContactAuthorizationPort {
  ContactAuthorization current = const ContactAuthorization(
    ContactAccess.notDetermined,
    canRequest: true,
  );
  ContactAuthorization result = const ContactAuthorization(
    ContactAccess.authorized,
  );
  int checks = 0, requests = 0;
  Completer<ContactAuthorization>? pending;
  @override
  Future<ContactAuthorization> check() async {
    checks++;
    return current;
  }

  @override
  Future<ContactAuthorization> request() async {
    requests++;
    current = await (pending?.future ?? Future.value(result));
    return current;
  }
}

class _Device implements DeviceContactSource {
  int reads = 0;
  ContactAccess access = ContactAccess.authorized;
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    reads++;
    expect(requestPermission, isFalse);
    return DeviceContactsSnapshot(access, const [
      DeviceContactRow(name: '合成联系人', phone: '2025550101'),
    ]);
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform $scale permission before selection and one read', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final port = _Port(), device = _Device();
        await _pump(tester, platform, scale, port, device);
        await tester.tap(find.byKey(const ValueKey('tab-1')));
        await tester.pumpAndSettle();
        expect(find.text('原页面'), findsOneWidget);
        expect(_selected(tester), 0);
        expect(device.reads, 0);
        expect(port.requests, 0);
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('contacts-permission-card')))
              .dy,
          closeTo(284, 0.1),
        );
        expect(
          MediaQuery.textScalerOf(
            tester.element(
              find.byKey(const ValueKey('contacts-permission-card')),
            ),
          ).scale(14),
          14 * scale,
        );
        expect(find.text('允许访问通讯录？'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('contacts-permission-cancel')),
        );
        await tester.pumpAndSettle();
        expect(_selected(tester), 0);
        expect(port.requests, 0);
        await tester.tap(find.byKey(const ValueKey('tab-1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('contacts-permission-confirm')),
        );
        await tester.pumpAndSettle();
        expect(_selected(tester), 1);
        expect(device.reads, 1);
        expect(port.requests, 1);
        await tester.tap(find.byKey(const ValueKey('tab-1')));
        await tester.pumpAndSettle();

        expect(device.reads, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
    testWidgets('$platform foreground revoke clears covered detail selection', (
      tester,
    ) async {
      final port = _Port()
        ..current = const ContactAuthorization(ContactAccess.authorized);
      final device = _Device();
      await _pump(tester, platform, 1, port, device);
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('合成联系人，2025550101'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContactTabEntryGate, skipOffstage: false)),
      );
      expect(container.read(contactsControllerProvider).selected, isNotNull);
      device.access = ContactAccess.denied;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(device.reads, 2);
      expect(container.read(contactsControllerProvider).selected, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    testWidgets(
      '$platform explicit settings return retains old tab until success',
      (tester) async {
        final port = _Port()
          ..result = const ContactAuthorization(ContactAccess.denied);
        final device = _Device();
        var settings = 0;
        await _pump(
          tester,
          platform,
          1,
          port,
          device,
          settings: () async {
            settings++;
          },
        );
        await tester.tap(find.byKey(const ValueKey('tab-1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('contacts-permission-confirm')),
        );
        await tester.pumpAndSettle();
        expect(find.text('开启通讯录权限'), findsOneWidget);
        expect(_selected(tester), 0);
        await tester.tap(
          find.byKey(const ValueKey('contacts-permission-confirm')),
        );
        await tester.pumpAndSettle();
        expect(settings, 1);
        expect(device.reads, 0);
        port.current = const ContactAuthorization(ContactAccess.limited);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(_selected(tester), 1);
        expect(device.reads, 1);
        expect(port.requests, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
    testWidgets('$platform switching another tab discards late authorization', (
      tester,
    ) async {
      final port = _Port()..pending = Completer<ContactAuthorization>();
      final device = _Device();
      await _pump(tester, platform, 1, port, device);
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('contacts-permission-confirm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      port.pending!.complete(
        const ContactAuthorization(ContactAccess.authorized),
      );
      await tester.pumpAndSettle();
      expect(_selected(tester), 2);
      expect(device.reads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('iOS consent fades without changing card size or center', (
    tester,
  ) async {
    final port = _Port(), device = _Device();
    await _pump(tester, TargetPlatform.iOS, 1, port, device);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final card = find.byKey(const ValueKey('contacts-permission-card'));
    final during = tester.getRect(card);
    await tester.pumpAndSettle();
    expect(tester.getRect(card), during);
    await tester.tap(find.byKey(const ValueKey('contacts-permission-cancel')));
    await tester.pumpAndSettle();
    expect(port.requests, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('account epoch release ignores late permission result', (
    tester,
  ) async {
    final port = _Port()..pending = Completer<ContactAuthorization>();
    final device = _Device();
    await _pump(tester, TargetPlatform.iOS, 1, port, device);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contacts-permission-confirm')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContactTabEntryGate, skipOffstage: false)),
    );
    container.read(_epoch.notifier).state++;
    await tester.pump();
    port.pending!.complete(
      const ContactAuthorization(ContactAccess.authorized),
    );
    await tester.pumpAndSettle();
    expect(_selected(tester), 0);
    expect(device.reads, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

int _selected(WidgetTester tester) =>
    tester.widget<FloatingNavigation>(find.byType(FloatingNavigation)).selected;

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  double scale,
  _Port port,
  _Device device, {
  Future<void> Function()? settings,
}) async {
  var tab = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
        contactsSharedFlowEnabledProvider.overrideWithValue(true),
        contactAuthorizationPortProvider.overrideWithValue(port),
        deviceContactSourceProvider.overrideWithValue(device),
        contactDirectoryRepositoryProvider.overrideWithValue(
          PreviewContacts().directory,
        ),
        contactSettingsLauncherProvider.overrideWithValue(
          settings ?? () async {},
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: child!,
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 568),
            textScaler: TextScaler.linear(scale),
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: tab == 1
                        ? const ContactsRoute(loadOnMount: false)
                        : const Center(child: Text('原页面')),
                  ),
                  ContactTabEntryGate(
                    selected: tab,
                    onSelected: (value) => setState(() => tab = value),
                    builder: (select) => FloatingNavigation(
                      selected: tab,
                      onSelected: select,
                      onDial: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
