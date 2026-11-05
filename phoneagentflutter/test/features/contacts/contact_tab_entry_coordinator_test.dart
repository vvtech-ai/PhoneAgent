import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_authorization.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contact_tab_entry_coordinator.dart';

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
  bool fail = false;
  @override
  Future<ContactAuthorization> check() async {
    checks++;
    if (fail) throw StateError('synthetic');
    return current;
  }

  @override
  Future<ContactAuthorization> request() async {
    requests++;
    return pending?.future ?? result;
  }
}

void main() {
  for (final ios in [false, true]) {
    test('$ios granted or limited enters without consent', () async {
      for (final access in [ContactAccess.authorized, ContactAccess.limited]) {
        final h = _Harness(ios)..port.current = ContactAuthorization(access);
        await h.c.select();
        expect(h.enters, 1);
        expect(h.dialogs, isEmpty);
        expect(h.port.requests, 0);
      }
    });
    test('$ios cancellation and first authorization', () async {
      final h = _Harness(ios)..accept = false;
      await h.c.select();
      expect(h.enters, 0);
      expect(h.port.requests, 0);
      expect(h.notices, ['需要通讯录权限才能使用此功能']);
      h.accept = true;
      await h.c.select();
      expect(h.enters, 1);
      expect(h.port.requests, 1);
    });
    test('$ios repeated taps, other tab and late permission result', () async {
      final h = _Harness(ios)..port.pending = Completer<ContactAuthorization>();
      final first = h.c.select();
      await Future<void>.delayed(Duration.zero);
      await h.c.select();
      expect(h.port.requests, 1);
      h.c.cancel();
      h.port.pending!.complete(
        const ContactAuthorization(ContactAccess.authorized),
      );
      await first;
      expect(h.enters, 0);
      expect(h.notices, isEmpty);
    });
    test('$ios settings return success denial and unrelated resume', () async {
      final h = _Harness(ios)
        ..port.result = const ContactAuthorization(ContactAccess.denied);
      await h.c.resumed();
      expect(h.port.checks, 0);
      await h.c.select();
      expect(h.settings, 1);
      await h.c.resumed();
      expect(h.enters, 0);
      expect(h.notices.last, '请在系统设置中开启通讯录权限');
      await h.c.select();
      h.port.current = const ContactAuthorization(ContactAccess.authorized);
      await h.c.resumed();
      await h.c.resumed();
      expect(h.enters, 1);
    });
    test('$ios settings launch failure and disposal', () async {
      final h = _Harness(ios)..settingsFail = true;
      h.port.result = const ContactAuthorization(ContactAccess.denied);
      await h.c.select();
      expect(h.notices, ['请在系统设置中开启通讯录权限']);
      h.c.dispose();
      await h.c.select();
      await h.c.resumed();
      expect(h.port.requests, 1);
    });
  }
  test(
    'Android retryable denial only notices, iOS denial goes to settings',
    () async {
      for (final ios in [false, true]) {
        final h = _Harness(ios)
          ..port.result = const ContactAuthorization(
            ContactAccess.denied,
            canRequest: true,
          );
        await h.c.select();
        expect(h.settings, ios ? 1 : 0);
        expect(h.enters, 0);
        expect(h.notices.length, ios ? 0 : 1);
      }
    },
  );
  test(
    'iOS denied entry skips request; Android keeps native consent',
    () async {
      for (final ios in [false, true]) {
        final h = _Harness(ios)
          ..port.current = const ContactAuthorization(ContactAccess.denied);
        await h.c.select();
        expect(
          h.dialogs.first,
          ios
              ? ContactPermissionDialogKind.settings
              : ContactPermissionDialogKind.consent,
        );
        expect(h.port.requests, ios ? 0 : 1);
      }
    },
  );
  test('settings resume during launch is queued and consumes once', () async {
    final h = _Harness(true)
      ..port.result = const ContactAuthorization(ContactAccess.denied);
    h.launching = Completer<void>();
    final selecting = h.c.select();
    await Future<void>.delayed(Duration.zero);
    h.port.current = const ContactAuthorization(ContactAccess.authorized);
    await h.c.resumed();
    await h.c.select();
    expect(h.enters, 0);
    h.launching!.complete();
    await selecting;
    await Future<void>.delayed(Duration.zero);
    expect(h.enters, 1);
    expect(h.port.checks, 2);
  });
  test('permission check failure does not request or navigate', () async {
    final h = _Harness(false)..port.fail = true;
    await h.c.select();
    expect(h.port.requests, 0);
    expect(h.enters, 0);
    expect(h.notices, ['无法检查通讯录权限，请重试']);
  });
}

class _Harness {
  _Harness(bool ios) {
    c = ContactTabEntryCoordinator(
      port: port,
      isIOS: ios,
      isActive: () => true,
      confirm: (kind) async {
        dialogs.add(kind);
        return accept;
      },
      openSettings: () async {
        settings++;
        if (settingsFail) throw StateError('synthetic');
        await launching?.future;
      },
      enter: () => enters++,
      notice: notices.add,
    );
  }
  final port = _Port();
  late final ContactTabEntryCoordinator c;
  bool accept = true, settingsFail = false;
  int enters = 0, settings = 0;
  Completer<void>? launching;
  final dialogs = <ContactPermissionDialogKind>[];
  final notices = <String>[];
}
