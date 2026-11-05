import '../domain/contact_records.dart';

/// Explicit browser preview only. No account, network or platform dependencies.
class PreviewContacts implements DeviceContactSource {
  final _entries = <String, ContactDirectoryEntry>{};

  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async =>
      DeviceContactsSnapshot(ContactAccess.authorized, const [
        DeviceContactRow(name: '演示联系人', phone: '2025550101'),
        DeviceContactRow(name: '演示联系人', phone: '2025550102'),
        DeviceContactRow(name: '演示餐厅', phone: '2025550103'),
      ]);

  // Separate view because the two ports intentionally have different load types.
  ContactDirectoryRepository get directory => _PreviewDirectory(_entries);
}

class _PreviewDirectory
    implements ContactDirectoryRepository, ContactDirectoryDeletionPort {
  _PreviewDirectory(this.entries);
  final Map<String, ContactDirectoryEntry> entries;
  @override
  Future<void> deleteRemark(String phoneKey) async {
    entries.remove(phoneKey);
  }

  @override
  Future<List<ContactDirectoryEntry>> load() async => entries.values.toList();
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async {
    final entry = ContactDirectoryEntry(
      phone: contact.phone,
      displayName: existing?.displayName ?? contact.name,
      primaryRelation: existing?.primaryRelation,
      speakingStyle: existing?.speakingStyle,
      description: remark.trim().isEmpty ? null : remark.trim(),
    );
    entries[contact.key] = entry;
    return entry;
  }
}
