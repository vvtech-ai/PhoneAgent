import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/contact_records.dart';

class ContactsState {
  const ContactsState({
    this.contacts = const [],
    this.directory = const [],
    this.access = ContactAccess.unknown,
    this.deviceLoading = false,
    this.directoryLoading = false,
    this.saving = false,
    this.deleting = false,
    this.deleteError = '',
    this.deviceError = '',
    this.directoryError = '',
    this.saveError = '',
    this.selected,
    this.editing = false,
    this.draft = '',
  });
  final List<ContactRecord> contacts;
  final List<ContactDirectoryEntry> directory;
  final ContactAccess access;
  final bool deviceLoading, directoryLoading, saving, editing, deleting;
  final String deleteError;
  final String deviceError, directoryError, saveError, draft;
  final ContactRecord? selected;

  ContactDirectoryEntry? entryFor(String key) {
    for (final entry in directory) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  String get remark =>
      selected == null ? '' : entryFor(selected!.key)?.description ?? '';

  ContactsState copy({
    List<ContactRecord>? contacts,
    List<ContactDirectoryEntry>? directory,
    ContactAccess? access,
    bool? deviceLoading,
    bool? directoryLoading,
    bool? saving,
    bool? deleting,
    String? deleteError,
    String? deviceError,
    String? directoryError,
    String? saveError,
    ContactRecord? selected,
    bool clearSelection = false,
    bool? editing,
    String? draft,
  }) => ContactsState(
    contacts: contacts ?? this.contacts,
    directory: directory ?? this.directory,
    access: access ?? this.access,
    deviceLoading: deviceLoading ?? this.deviceLoading,
    directoryLoading: directoryLoading ?? this.directoryLoading,
    saving: saving ?? this.saving,
    deleting: deleting ?? this.deleting,
    deleteError: deleteError ?? this.deleteError,
    deviceError: deviceError ?? this.deviceError,
    directoryError: directoryError ?? this.directoryError,
    saveError: saveError ?? this.saveError,
    selected: clearSelection ? null : selected ?? this.selected,
    editing: editing ?? this.editing,
    draft: draft ?? this.draft,
  );
}

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._device, this._directory)
    : super(const ContactsState());
  final DeviceContactSource _device;
  final ContactDirectoryRepository _directory;
  int _directoryGeneration = 0, _detailGeneration = 0, _deviceGeneration = 0;
  Future<void>? _devicePending;

  Future<void> loadDevice({bool requestPermission = false}) {
    if (!mounted) return Future.value();
    return _devicePending ??= _loadDevice(requestPermission);
  }

  Future<void> _loadDevice(bool requestPermission) async {
    final generation = ++_deviceGeneration;
    state = state.copy(deviceLoading: true, deviceError: '');
    try {
      // Normalize synchronous adapter failures to an async completion, so the
      // pending handle is assigned before its finally block releases it.
      final result = await Future.sync(
        () => _device.load(requestPermission: requestPermission),
      );
      if (!mounted || generation != _deviceGeneration) return;
      final contacts = result.canRead
          ? ContactRecord.fromRows(result.rows)
          : const <ContactRecord>[];
      final selected = state.selected;
      state = state.copy(
        access: result.access,
        deviceLoading: false,
        contacts: contacts,
      );
      // A limited subset or deleted/renamed record must not leave its old
      // detail and editable draft available after a successful system reread.
      if (!result.canRead ||
          selected != null &&
              !contacts.any(
                (row) => row.key == selected.key && row.name == selected.name,
              )) {
        closeDetail();
      }
    } catch (_) {
      if (mounted && generation == _deviceGeneration) {
        state = state.copy(deviceLoading: false, deviceError: '读取本机联系人失败，请重试');
      }
    } finally {
      if (generation == _deviceGeneration) _devicePending = null;
    }
  }

  /// v65 Empty clears only the current in-memory device list, never OS data.
  void clearDeviceForDeveloper() {
    if (!mounted) return;
    ++_deviceGeneration;
    _devicePending = null;
    closeDetail();
    state = state.copy(
      contacts: const [],
      deviceLoading: false,
      deviceError: '',
    );
  }

  Future<void> loadDirectory() async {
    if (!mounted || state.directoryLoading || state.saving || state.deleting) {
      return;
    }
    final generation = ++_directoryGeneration;
    state = state.copy(directoryLoading: true, directoryError: '');
    try {
      final entries = await _directory.load();
      if (!mounted || generation != _directoryGeneration) return;
      state = state.copy(
        directory: List.unmodifiable(entries),
        directoryLoading: false,
      );
    } catch (_) {
      if (mounted && generation == _directoryGeneration) {
        state = state.copy(
          directoryLoading: false,
          directoryError: '联系人备注加载失败，请重试',
        );
      }
    }
  }

  void openDetail(ContactRecord contact) {
    ++_detailGeneration;
    state = state.copy(
      selected: contact,
      editing: false,
      draft: '',
      saveError: '',
      deleteError: '',
    );
  }

  void closeDetail() {
    ++_detailGeneration;
    state = state.copy(
      clearSelection: true,
      editing: false,
      draft: '',
      saveError: '',
      deleteError: '',
    );
  }

  void beginEdit() {
    if (state.selected == null ||
        state.directoryLoading ||
        state.saving ||
        state.deleting) {
      return;
    }
    state = state.copy(editing: true, draft: state.remark, saveError: '');
  }

  void editRemark(String value) {
    if (!state.editing || state.saving) return;
    state = state.copy(draft: value, saveError: '');
  }

  void cancelEdit() {
    if (state.saving) return;
    state = state.copy(editing: false, draft: '', saveError: '');
  }

  bool get canDeleteRemark =>
      _directory is ContactDirectoryDeletionPort &&
      state.selected != null &&
      state.entryFor(state.selected!.key) != null &&
      !state.directoryLoading &&
      !state.saving &&
      !state.deleting &&
      !state.editing;

  Future<bool> deleteRemark(String expectedKey) async {
    if (!mounted || !canDeleteRemark || state.selected!.key != expectedKey) {
      return false;
    }
    final detailGeneration = _detailGeneration;
    ++_directoryGeneration;
    state = state.copy(deleting: true, deleteError: '');
    try {
      await (_directory as ContactDirectoryDeletionPort).deleteRemark(
        expectedKey,
      );
      if (!mounted) return false;
      final sameDetail =
          detailGeneration == _detailGeneration &&
          state.selected?.key == expectedKey;
      state = state.copy(
        deleting: false,
        directory: List.unmodifiable(
          state.directory.where((entry) => entry.key != expectedKey),
        ),
      );
      return sameDetail;
    } catch (_) {
      if (mounted) {
        state = state.copy(
          deleting: false,
          deleteError: detailGeneration == _detailGeneration
              ? '删除联系人备注失败，请重试'
              : state.deleteError,
        );
      }
      return false;
    }
  }

  Future<bool> saveRemark() async {
    final contact = state.selected;
    if (contact == null ||
        contact.key.isEmpty ||
        !state.editing ||
        state.saving ||
        state.deleting) {
      return false;
    }
    final detailGeneration = _detailGeneration;
    final draft = state.draft;
    ++_directoryGeneration; // An older GET must not roll back a successful POST.
    state = state.copy(saving: true, directoryLoading: false, saveError: '');
    try {
      final saved = await _directory.saveRemark(
        contact: contact,
        remark: draft,
        existing: state.entryFor(contact.key),
      );
      if (!mounted) return false;
      if (saved.key != contact.key) throw StateError('Mismatched contact');
      final updated = state.directory.toList();
      final index = updated.indexWhere((entry) => entry.key == saved.key);
      if (index < 0) {
        updated.add(saved);
      } else {
        updated[index] = saved;
      }
      final sameDetail = detailGeneration == _detailGeneration;
      // v65 closes the editor only when the returned remark matches submission.
      final acceptedDraft = (saved.description ?? '').trim() == draft.trim();
      state = state.copy(
        directory: List.unmodifiable(updated),
        saving: false,
        editing: sameDetail ? !acceptedDraft : state.editing,
        draft: sameDetail && acceptedDraft ? '' : state.draft,
      );
      return true;
    } catch (_) {
      if (mounted) {
        state = state.copy(
          saving: false,
          saveError: detailGeneration == _detailGeneration
              ? '保存联系人备注失败，请重试'
              : state.saveError,
        );
      }
      return false;
    }
  }
}
