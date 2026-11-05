import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';

const a = ContactRecord(
  name: '合成甲',
  phone: '13800000000',
  systemDialPhone: '13800000000',
);
const b = ContactRecord(
  name: '合成乙',
  phone: '13800000001',
  systemDialPhone: '13800000001',
);
void main() {
  late _Device device;
  late _Directory repo;
  late ContactsController c;
  setUp(() {
    device = _Device();
    repo = _Directory();
    c = ContactsController(device, repo);
  });
  tearDown(() {
    if (c.mounted) c.dispose();
  });
  test(
    'independent loads; backend-only entries never become device contacts',
    () async {
      await Future.wait([c.loadDevice(), c.loadDirectory()]);
      expect(c.state.contacts.single.name, '合成甲');
      expect(device.requested, isFalse);
      device.gate = null;
      device.failSynchronously = true;
      await c.loadDevice();
      expect(c.state.deviceError, isNotEmpty);
      device.failSynchronously = false;
      await c.loadDevice();
      expect(c.state.contacts.single.name, '合成甲');
      expect(c.state.directory.length, 1);
      c.openDetail(a);
      expect(c.state.remark, '旧备注');
      repo.fail = true;
      await c.loadDirectory();
      expect(c.state.contacts.length, 1);
      expect(c.state.remark, '旧备注');
      expect(c.state.directoryError, isNotEmpty);
    },
  );
  test(
    'Empty clears detail and pending device read, not permission or directory',
    () async {
      await Future.wait([c.loadDevice(), c.loadDirectory()]);
      c.openDetail(a);
      c.beginEdit();
      device.gate = Completer();
      final pending = c.loadDevice();
      c.clearDeviceForDeveloper();
      expect(c.state.selected, isNull);
      expect(c.state.editing, isFalse);
      expect(c.state.access, ContactAccess.authorized);
      expect(c.state.directory.single.description, '旧备注');
      device.gate!.complete(
        DeviceContactsSnapshot(ContactAccess.authorized, const [
          DeviceContactRow(name: '旧数据', phone: '13800000000'),
        ]),
      );
      await pending;
      expect(c.state.contacts, isEmpty);
      device.gate = null;
      await c.loadDevice();
      expect(c.state.contacts.single.name, '合成甲');
      expect(device.requested, isFalse);
    },
  );
  test(
    'Filled waits for an existing device read instead of reporting early success',
    () async {
      device.gate = Completer();
      final first = c.loadDevice();
      var finished = false;
      final second = c.loadDevice().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      device.gate!.complete(DeviceContactsSnapshot(ContactAccess.denied));
      await Future.wait([first, second]);
      expect(finished, isTrue);
      expect(device.requested, isFalse);
    },
  );
  test(
    'denied access clears device list/detail but not backend directory',
    () async {
      await Future.wait([c.loadDevice(), c.loadDirectory()]);
      c.openDetail(a);
      device.access = ContactAccess.denied;
      await c.loadDevice(requestPermission: true);
      expect(device.requested, isTrue);
      expect(c.state.contacts, isEmpty);
      expect(c.state.selected, isNull);
      expect(c.state.access, ContactAccess.denied);
      expect(c.state.directory, isNotEmpty);
    },
  );
  test(
    'failed save keeps old remark/draft and explicit retry succeeds',
    () async {
      await c.loadDirectory();
      c.openDetail(a);
      c.beginEdit();
      c.editRemark('新备注');
      repo.fail = true;
      expect(await c.saveRemark(), isFalse);
      expect(c.state.draft, '新备注');
      expect(c.state.remark, '旧备注');
      expect(c.state.editing, isTrue);
      repo.fail = false;
      expect(await c.saveRemark(), isTrue);
      expect(c.state.remark, '新备注');
      expect(c.state.editing, isFalse);
    },
  );
  test(
    'single flight and changed detail not overwritten by old save',
    () async {
      await c.loadDirectory();
      c.openDetail(a);
      c.beginEdit();
      c.editRemark('新备注');
      repo.saveGate = Completer<ContactDirectoryEntry>();
      final pending = c.saveRemark();
      expect(await c.saveRemark(), isFalse);
      c.openDetail(b);
      repo.saveGate!.complete(
        const ContactDirectoryEntry(phone: '13800000000', description: '新备注'),
      );
      expect(await pending, isTrue);
      expect(repo.saves, 1);
      expect(c.state.selected, b);
      expect(c.state.remark, '');
      c.openDetail(a);
      expect(c.state.remark, '新备注');
    },
  );
  test('GET started before save cannot roll back saved remark', () async {
    await c.loadDirectory();
    c.openDetail(a);
    c.beginEdit();
    c.editRemark('新备注');
    repo.loadGate = Completer<List<ContactDirectoryEntry>>();
    final oldLoad = c.loadDirectory();
    await c.saveRemark();
    repo.loadGate!.complete(const [
      ContactDirectoryEntry(phone: '13800000000', description: '旧备注'),
    ]);
    await oldLoad;
    expect(c.state.remark, '新备注');
    expect(c.state.directoryLoading, isFalse);
  });
  test(
    'server remark differing from submission keeps editor like v65',
    () async {
      await c.loadDirectory();
      c.openDetail(a);
      c.beginEdit();
      c.editRemark('新备注');
      repo.saveGate = Completer<ContactDirectoryEntry>();
      final pending = c.saveRemark();
      repo.saveGate!.complete(
        const ContactDirectoryEntry(
          phone: '13800000000',
          description: '服务端返回的备注',
        ),
      );
      expect(await pending, isTrue);
      expect(c.state.remark, '服务端返回的备注');
      expect(c.state.editing, isTrue);
      expect(c.state.draft, '新备注');
    },
  );
  test('disposed account ignores save result', () async {
    await c.loadDirectory();
    c.openDetail(a);
    c.beginEdit();
    repo.saveGate = Completer<ContactDirectoryEntry>();
    final pending = c.saveRemark();
    c.dispose();
    repo.saveGate!.complete(const ContactDirectoryEntry(phone: '13800000000'));
    expect(await pending, isFalse);
  });
  test(
    'disposed controller ignores pending device and directory loads',
    () async {
      device.gate = Completer<DeviceContactsSnapshot>();
      repo.loadGate = Completer<List<ContactDirectoryEntry>>();
      final reads = Future.wait([c.loadDevice(), c.loadDirectory()]);
      c.dispose();
      device.gate!.complete(DeviceContactsSnapshot(ContactAccess.authorized));
      repo.loadGate!.complete(const []);
      await reads;
      expect(c.mounted, isFalse);
    },
  );
}

class _Device implements DeviceContactSource {
  Completer<DeviceContactsSnapshot>? gate;
  ContactAccess access = ContactAccess.authorized;
  bool requested = false;
  bool failSynchronously = false;
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) {
    if (failSynchronously) throw StateError('synthetic adapter failure');
    requested = requestPermission;
    if (gate != null) return gate!.future;
    return Future.value(
      DeviceContactsSnapshot(access, const [
        DeviceContactRow(name: '合成甲', phone: '13800000000'),
      ]),
    );
  }
}

class _Directory implements ContactDirectoryRepository {
  bool fail = false;
  int saves = 0;
  Completer<List<ContactDirectoryEntry>>? loadGate;
  Completer<ContactDirectoryEntry>? saveGate;
  @override
  Future<List<ContactDirectoryEntry>> load() async {
    if (fail) throw StateError('synthetic');
    return loadGate != null
        ? loadGate!.future
        : const [
            ContactDirectoryEntry(phone: '13800000000', description: '旧备注'),
          ];
  }

  @override
  Future<ContactDirectoryEntry> saveRemark({
    required ContactRecord contact,
    required String remark,
    ContactDirectoryEntry? existing,
  }) async {
    saves++;
    if (fail) throw StateError('synthetic');
    return saveGate != null
        ? saveGate!.future
        : ContactDirectoryEntry(
            phone: contact.phone,
            description: remark.trim(),
          );
  }
}
