import '../../../../core/design/native_action_style.dart';
import '../../../../core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/migration_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/contact_providers.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_notice.dart';
import '../../data/preview_contacts.dart';
import '../../domain/contact_records.dart';
import '../controller/contacts_controller.dart';
import '../widgets/contact_remark_editor.dart';
import 'contact_detail_page.dart';
import 'contacts_page.dart';
import 'contact_actions.dart';

class ContactsRoute extends ConsumerStatefulWidget {
  const ContactsRoute({super.key, this.loadOnMount = true});
  final bool loadOnMount;
  @override
  ConsumerState<ContactsRoute> createState() => _ContactsRouteState();
}

class _ContactsRouteState extends ConsumerState<ContactsRoute> {
  PreviewContacts? _preview;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(contactsSharedFlowEnabledProvider)) {
      return _ContactsHost(loadOnMount: widget.loadOnMount);
    }
    final preview = _preview;
    if (preview == null) {
      return Column(
        children: [
          const NativePageHeader(title: '联系人', showBack: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 128),
              children: [
                const Text('浏览器无法读取手机系统通讯录。', style: ShellTokens.subtitle),
                const SizedBox(height: 12),
                const Text(
                  'Android / iOS 使用手机通讯录；不会自动上传整本通讯录。',
                  style: ShellTokens.subtitle,
                ),
                if (migrationPreviewsEnabled) ...[
                  const SizedBox(height: 24),
                  NativeActionSurface(
                    child: FilledButton(
                      onPressed: () =>
                          setState(() => _preview = PreviewContacts()),
                      child: const Text('进入联系人交互演练（MOCK）'),
                    ),
                  ),
                  const Text(
                    '演练使用内存中的合成联系人与备注，不写入真实账户。',
                    style: ShellTokens.subtitle,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return ProviderScope(
      overrides: [
        contactsControllerProvider.overrideWith((ref) {
          final controller = ContactsController(preview, preview.directory);
          controller.loadDevice();
          controller.loadDirectory();
          return controller;
        }),
      ],
      child: _ContactsHost(
        preview: true,
        onExitPreview: () => setState(() => _preview = null),
      ),
    );
  }
}

class _ContactsHost extends ConsumerStatefulWidget {
  const _ContactsHost({
    this.preview = false,
    this.onExitPreview,
    this.loadOnMount = true,
  });
  final bool loadOnMount;
  final bool preview;
  final VoidCallback? onExitPreview;
  @override
  ConsumerState<_ContactsHost> createState() => _ContactsHostState();
}

class _ContactsHostState extends ConsumerState<_ContactsHost>
    with WidgetsBindingObserver {
  bool _detailOpen = false;
  bool _settingsBusy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.preview && widget.loadOnMount) {
      Future.microtask(() {
        if (mounted) ref.read(contactsControllerProvider.notifier).loadDevice();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !widget.preview &&
        widget.loadOnMount) {
      ref.read(contactsControllerProvider.notifier).loadDevice();
    }
  }

  Future<void> _open(ContactRecord contact) async {
    if (_detailOpen || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final available = ref
        .read(contactsControllerProvider)
        .contacts
        .any((row) => row.name == contact.name && row.key == contact.key);
    if (!available) return;
    _detailOpen = true;
    final controller = ref.read(contactsControllerProvider.notifier);
    controller.openDetail(contact);
    final container = ProviderScope.containerOf(context);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => UncontrolledProviderScope(
            container: container,
            child: _ContactDetailRoute(preview: widget.preview),
          ),
        ),
      );
    } finally {
      _detailOpen = false;
      if (controller.mounted) controller.closeDetail();
    }
  }

  Future<void> _refresh() async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final controller = ref.read(contactsControllerProvider.notifier);
    await Future.wait([controller.loadDevice(), controller.loadDirectory()]);
  }

  void _requestPermission() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    ref
        .read(contactsControllerProvider.notifier)
        .loadDevice(requestPermission: true);
  }

  Future<void> _settings() async {
    if (!mounted ||
        _settingsBusy ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _settingsBusy = true;
    final owner = ref.read(contactsControllerProvider.notifier);
    try {
      await ref.read(contactSettingsLauncherProvider)();
    } catch (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          identical(owner, ref.read(contactsControllerProvider.notifier))) {
        showNativeNotice(context, '无法打开系统设置，请稍后重试');
      }
    } finally {
      _settingsBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    return Column(
      children: [
        if (widget.preview) _PreviewBanner(onExit: widget.onExitPreview),
        Expanded(
          child: ContactsPage(
            state: state,
            onOpen: _open,
            onSettings: widget.preview ? null : _settings,
            onRefresh: _refresh,
            onRequestPermission: _requestPermission,
          ),
        ),
      ],
    );
  }
}

class _ContactDetailRoute extends ConsumerWidget {
  const _ContactDetailRoute({required this.preview});
  final bool preview;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        ref.read(contactsControllerProvider).editing) {
      return;
    }
    final controller = ref.read(contactsControllerProvider.notifier);
    controller.beginEdit();
    if (!ref.read(contactsControllerProvider).editing) return;
    final key = ref.read(contactsControllerProvider).selected?.key;
    final container = ProviderScope.containerOf(context);
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF5FFFFFF),
      barrierColor: const Color(0x380F0F12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isDismissible: true,
      enableDrag: false,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const ContactRemarkEditor(),
      ),
    );
    if (!controller.mounted) return;
    controller.cancelEdit();
    if (accepted == true &&
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        ref.read(contactsControllerProvider).selected?.key == key) {
      showNativeNotice(context, '已保存联系人备注');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final controller = ref.read(contactsControllerProvider.notifier);
    if (!controller.canDeleteRemark ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final key = ref.read(contactsControllerProvider).selected!.key;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const NativeConfirmationDialog(
        title: '删除联系人备注？',
        message: '本机通讯录联系人不会被删除。',
        confirmLabel: '删除',
        danger: true,
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final deleted = await controller.deleteRemark(key);
    if (!context.mounted ||
        !controller.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        ref.read(contactsControllerProvider).selected?.key != key) {
      return;
    }
    final error = ref.read(contactsControllerProvider).deleteError;
    if (deleted) {
      Navigator.pop(context);
    } else if (error.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => NativeBusinessDialog(
          title: '删除失败',
          message: error,
          showDismiss: false,
          confirmLabel: '确定',
          onConfirm: () => Navigator.pop(dialogContext),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final owner = ref.read(contactsControllerProvider.notifier);
    bool currentSelection() =>
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        identical(owner, ref.read(contactsControllerProvider.notifier)) &&
        ref.read(contactsControllerProvider).selected?.key ==
            state.selected?.key &&
        ref.read(contactsControllerProvider).selected?.name ==
            state.selected?.name &&
        state.selected != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: NativePageBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (preview) const _PreviewBanner(),
              Expanded(
                child: ContactDetailPage(
                  state: state,
                  onBack: () {
                    if (ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.pop(context);
                    }
                  },
                  onEdit: () => _edit(context, ref),
                  onDelete:
                      ref
                          .read(contactsControllerProvider.notifier)
                          .canDeleteRemark
                      ? () => _delete(context, ref)
                      : null,
                  onRetry: () {
                    if (currentSelection()) owner.loadDirectory();
                  },
                  onCall: () {
                    if (currentSelection()) {
                      showContactDial(
                        context,
                        state.selected!,
                        preview: preview,
                      );
                    }
                  },
                  onTask: () {
                    if (currentSelection()) {
                      showContactSkills(
                        context,
                        state.selected!,
                        preview: preview,
                      );
                    }
                  },
                  dialBusy: ref.watch(contactSystemDialControllerProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({this.onExit});
  final VoidCallback? onExit;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFFFF3CD),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      children: [
        const Expanded(
          child: Text('MOCK · 合成联系人 / 内存备注', style: TextStyle(fontSize: 12)),
        ),
        if (onExit != null)
          TextButton(onPressed: onExit, child: const Text('退出演练')),
      ],
    ),
  );
}
