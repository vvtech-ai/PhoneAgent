import 'package:flutter/foundation.dart';
import '../../../contacts/data/preview_contacts.dart';
import '../../../contacts/presentation/controller/contacts_controller.dart';
import '../../../dialer/data/app_dial_recent_source.dart';
import '../../../dialer/data/preview_app_call_record_store.dart';
import '../../../dialer/domain/dial_recent_call.dart';
import '../../../dialer/domain/dial_recent_source.dart';
import '../../../dialer/presentation/controller/dial_recent_controller.dart';
import 'developer_list_controller.dart';

class AppCallRecordsPreviewController extends ChangeNotifier {
  AppCallRecordsPreviewController() {
    final source = PreviewContacts();
    contacts = ContactsController(source, source.directory);
    recent = DialRecentController(
      const _PreviewSystemRecords(),
      AppDialRecentSource(store.repository),
    );
    lists = DeveloperListController(
      records: store.repository,
      refreshTasks: () async {
        taskRefreshes++;
        return true;
      },
      reloadContacts: () async {
        await contacts.loadDevice();
        return true;
      },
      clearContacts: contacts.clearDeviceForDeveloper,
    );
    _remove = [
      contacts.addListener((value) {
        contactState = value;
        _notify();
      }),
      recent.addListener((value) {
        recentState = value;
        _notify();
      }),
      lists.addListener((value) {
        listState = value;
        _notify();
      }),
    ];
  }
  final store = PreviewAppCallRecordStore();
  late final ContactsController contacts;
  late final DialRecentController recent;
  late final DeveloperListController lists;
  late final List<VoidCallback> _remove;
  ContactsState contactState = const ContactsState();
  DialRecentState recentState = const DialRecentState();
  DeveloperListState listState = const DeveloperListState();
  bool busy = false, _closed = false;
  int taskRefreshes = 0, _id = 0;
  String selection = '', error = '';
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    await contacts.loadDevice();
    if (!_closed) await recent.load();
  }

  void failWrite(bool value) {
    store.failWrite = value;
    _notify();
  }

  void select(DialRecentCall record) {
    selection =
        '${record.restorablePhone} · ${record.countryIso} · ${record.callerLanguage}';
    _notify();
  }

  Future<void> addTranslation() async {
    if (_closed || busy || listState.busy) return;
    busy = true;
    error = '';
    _notify();
    try {
      await store.repository.append(
        DialRecentCall(
          id: 'mock-${++_id}',
          phone: '+12025550101',
          name: '合成翻译通话',
          startedAtMillis: DateTime.now().millisecondsSinceEpoch,
          source: DialRecentSource.app,
          kind: DialRecentKind.translation,
          countryIso: 'US',
          callerLanguage: 'zh',
          peerLanguage: 'en',
        ),
      );
    } catch (_) {
      error = '合成记录保存失败';
    }
    if (_closed) return;
    busy = false;
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    for (final remove in _remove) {
      remove();
    }
    lists.dispose();
    recent.dispose();
    contacts.dispose();
    store.repository.close();
    super.dispose();
  }
}

class _PreviewSystemRecords implements DialRecentCallSource {
  const _PreviewSystemRecords();
  @override
  Future<DialRecentSnapshot> load() async =>
      const DialRecentSnapshot(DialRecentAccess.ready, [
        DialRecentCall(
          id: 'synthetic-system',
          phone: '+12025550102',
          name: '合成系统记录（清空不影响）',
          startedAtMillis: 1,
          source: DialRecentSource.system,
        ),
      ]);
}
