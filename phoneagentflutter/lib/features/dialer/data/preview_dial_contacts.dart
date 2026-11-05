import '../../contacts/domain/contact_records.dart';

/// Synthetic dialer-only fixture; never mixed into the device directory.
class PreviewDialContacts implements DeviceContactSource {
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async =>
      DeviceContactsSnapshot(ContactAccess.authorized, const [
        DeviceContactRow(
          name: '张三（合成）',
          phone: '+12025550101',
          contactId: 'preview:zhang',
        ),
        DeviceContactRow(
          name: '张三（合成）',
          phone: '+12025550102',
          contactId: 'preview:zhang',
        ),
        DeviceContactRow(
          name: 'Alice Bob（合成）',
          phone: '+12025550103',
          contactId: 'preview:alice',
        ),
      ]);
}
