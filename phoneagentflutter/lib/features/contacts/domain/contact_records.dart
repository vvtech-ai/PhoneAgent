import 'contact_phone_policy.dart';

enum ContactAccess {
  unknown,
  notDetermined,
  denied,
  restricted,
  authorized,
  limited,
  unsupported,
}

class DeviceContactRow {
  const DeviceContactRow({
    required this.name,
    required this.phone,
    this.normalizedPhone = '',
    this.label = '',
    this.contactId = '',
  });
  final String name, phone, normalizedPhone, label, contactId;
}

class DeviceContactsSnapshot {
  DeviceContactsSnapshot(this.access, [List<DeviceContactRow> rows = const []])
    : rows = List.unmodifiable(rows);
  final ContactAccess access;
  final List<DeviceContactRow> rows;
  bool get canRead =>
      access == ContactAccess.authorized || access == ContactAccess.limited;
}

abstract interface class DeviceContactSource {
  Future<DeviceContactsSnapshot> load({bool requestPermission = false});
}

class ContactRecord {
  const ContactRecord({
    required this.name,
    required this.phone,
    required this.systemDialPhone,
  });
  final String name, phone, systemDialPhone;
  String get key => ContactPhonePolicy.directoryKey(phone);

  static List<ContactRecord> fromRows(List<DeviceContactRow> rows) {
    final records = <String, ContactRecord>{};
    for (final row in rows) {
      final phone = ContactPhonePolicy.resolve(
        row.phone,
        normalized: row.normalizedPhone,
      );
      if (phone == null) continue;
      final name = row.name.trim().isEmpty ? '未知联系人' : row.name.trim();
      final key = '$name\u0000${phone.lookup}';
      records.putIfAbsent(
        key,
        () => ContactRecord(
          name: name,
          phone: phone.lookup,
          systemDialPhone: row.phone.trim().isEmpty
              ? phone.lookup
              : row.phone.trim(),
        ),
      );
    }
    final result = records.values.toList()
      ..sort((a, b) {
        final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return order == 0 ? a.phone.compareTo(b.phone) : order;
      });
    return List.unmodifiable(result);
  }
}

class ContactDirectoryEntry {
  const ContactDirectoryEntry({
    required this.phone,
    this.displayName,
    this.primaryRelation,
    this.speakingStyle,
    this.description,
    this.updatedAt,
  });
  final String phone;
  final String? displayName,
      primaryRelation,
      speakingStyle,
      description,
      updatedAt;
  String get key => ContactPhonePolicy.directoryKey(phone);
}

abstract interface class ContactDirectoryRepository {
  Future<List<ContactDirectoryEntry>> load();
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  });
}

abstract interface class ContactDirectoryDeletionPort {
  Future<void> deleteRemark(String phoneKey);
}
