import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';

const a = ContactRecord(
  name: '演示联系人',
  phone: '2025550101',
  systemDialPhone: '2025550101',
);
const b = ContactRecord(
  name: '演示联系人',
  phone: '2025550102',
  systemDialPhone: '2025550102',
);

class _Directory
    implements ContactDirectoryRepository, ContactDirectoryDeletionPort {
  final entries = <ContactDirectoryEntry>[
    const ContactDirectoryEntry(phone: '2025550101', description: '测试备注'),
  ];
  final requests = <String>[];
  Completer<void>? gate;
  @override
  Future<List<ContactDirectoryEntry>> load() async => entries.toList();
  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteRemark(String key) async {
    requests.add(key);
    await gate?.future;
    entries.removeWhere((entry) => entry.key == key);
  }
}

void main() {
  late _Directory directory;
  late ContactsController controller;
  setUp(() async {
    directory = _Directory();
    controller = ContactsController(PreviewContacts(), directory);
    await controller.loadDevice();
    await controller.loadDirectory();
    controller.openDetail(a);
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'delete deduplicates and only removes directory entry not OS contacts',
    () async {
      directory.gate = Completer<void>();
      final oldContacts = controller.state.contacts;
      final pending = controller.deleteRemark(a.key);
      expect(controller.state.deleting, isTrue);
      expect(await controller.deleteRemark(a.key), isFalse);
      controller.beginEdit();
      expect(controller.state.editing, isFalse);
      await controller.loadDirectory();
      directory.gate!.complete();
      expect(await pending, isTrue);
      expect(directory.requests, [a.key]);
      expect(controller.state.directory, isEmpty);
      expect(controller.state.contacts, same(oldContacts));
      expect(controller.state.selected, a);
      expect(controller.canDeleteRemark, isFalse);
    },
  );
  test('failure preserves entry and allows only explicit retry', () async {
    directory.gate = Completer<void>();
    final pending = controller.deleteRemark(a.key);
    directory.gate!.completeError(StateError('synthetic'));
    expect(await pending, isFalse);
    expect(controller.state.remark, '测试备注');
    expect(controller.state.deleteError, '删除联系人备注失败，请重试');
    expect(directory.requests, [a.key]);
    directory.gate = null;
    expect(await controller.deleteRemark(a.key), isTrue);
    expect(directory.requests, [a.key, a.key]);
  });
  test(
    'late delete updates original key but does not close newer detail',
    () async {
      directory.gate = Completer<void>();
      final pending = controller.deleteRemark(a.key);
      controller.openDetail(b);
      directory.gate!.complete();
      expect(await pending, isFalse);
      expect(controller.state.selected, b);
      expect(controller.state.directory, isEmpty);
      expect(controller.state.deleteError, isEmpty);
    },
  );
  test(
    'wrong key editing absent entry and disposed owner cannot delete',
    () async {
      expect(await controller.deleteRemark(b.key), isFalse);
      controller.beginEdit();
      expect(await controller.deleteRemark(a.key), isFalse);
      controller.cancelEdit();
      controller.openDetail(b);
      expect(await controller.deleteRemark(b.key), isFalse);
      controller.openDetail(a);
      directory.gate = Completer<void>();
      final pending = controller.deleteRemark(a.key);
      controller.dispose();
      directory.gate!.complete();
      expect(await pending, isFalse);
    },
  );
}
