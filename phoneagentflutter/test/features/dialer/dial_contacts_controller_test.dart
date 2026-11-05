import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_contacts_controller.dart';

class Source implements DeviceContactSource {
  final requests = <bool>[];
  Future<DeviceContactsSnapshot> Function() next = () async =>
      DeviceContactsSnapshot(ContactAccess.authorized, const [
        DeviceContactRow(name: '合成联系人', phone: '2025550101'),
      ]);
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) {
    requests.add(requestPermission);
    return next();
  }
}

void main() {
  late Source source;
  late DialContactsController controller;
  setUp(() {
    source = Source();
    controller = DialContactsController(
      source,
      const DialSuggestionPolicy(LpinyinContactDictionary()),
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test('load is silent and permission revocation clears cached rows', () async {
    await controller.load();
    expect(controller.state.entries, hasLength(1));
    source.next = () async => DeviceContactsSnapshot(ContactAccess.denied);
    await controller.load();
    expect(controller.state.entries, isEmpty);
    expect(controller.state.access, ContactAccess.denied);
    expect(source.requests, [false, false]);
  });
  test('load single-flight clears stale values and ignores disposal', () async {
    await controller.load();
    final deferred = Completer<DeviceContactsSnapshot>();
    source.next = () => deferred.future;
    final pending = controller.load();
    await controller.load();
    expect(controller.state.loading, isTrue);
    expect(controller.state.entries, isEmpty);
    expect(source.requests, hasLength(2));
    controller.dispose();
    deferred.complete(DeviceContactsSnapshot(ContactAccess.authorized));
    await pending;
  });
  test(
    'failed read clears data and retry restores limited access rows',
    () async {
      await controller.load();
      source.next = () async => throw StateError('test');
      await controller.load();
      expect(controller.state.failed, isTrue);
      expect(controller.state.entries, isEmpty);
      source.next = () async => DeviceContactsSnapshot(
        ContactAccess.limited,
        const [DeviceContactRow(name: '合成新联系人', phone: '2025550102')],
      );
      await controller.load();
      expect(controller.state.failed, isFalse);
      expect(controller.state.entries.single.name, '合成新联系人');
    },
  );
}
