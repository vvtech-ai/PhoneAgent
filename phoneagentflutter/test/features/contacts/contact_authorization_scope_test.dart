import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';

class _Device implements DeviceContactSource {
  ContactAccess access = ContactAccess.authorized;
  List<DeviceContactRow> rows = const [
    DeviceContactRow(name: '合成联系人', phone: '2025550101'),
  ];
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async =>
      DeviceContactsSnapshot(access, rows);
}

void main() {
  for (final access in [
    ContactAccess.limited,
    ContactAccess.authorized,
    ContactAccess.denied,
  ]) {
    test(
      'removed selection/draft clears on successful reread $access',
      () async {
        final device = _Device();
        final c = ContactsController(device, PreviewContacts().directory);
        addTearDown(c.dispose);
        await c.loadDevice();
        c.openDetail(c.state.contacts.single);
        c.beginEdit();
        c.editRemark('仅内存合成草稿');
        device.access = access;
        device.rows = const [DeviceContactRow(name: '另一合成联系人', phone: '2025550102')];
        await c.loadDevice();
        expect(c.state.selected, isNull);
        expect(c.state.editing, isFalse);
        expect(c.state.draft, isEmpty);
        expect(c.state.contacts.length, access == ContactAccess.denied ? 0 : 1);
      },
    );
  }
  test(
    'unchanged authorized selection retains draft and disposed retry does no IO',
    () async {
      final device = _Device();
      final c = ContactsController(device, PreviewContacts().directory);
      await c.loadDevice();
      c.openDetail(c.state.contacts.single);
      c.beginEdit();
      c.editRemark('合成草稿');
      device.access = ContactAccess.limited;
      await c.loadDevice();
      expect(c.state.selected, isNotNull);
      expect(c.state.draft, '合成草稿');
      c.dispose();
      await c.loadDirectory();
    },
  );
}
