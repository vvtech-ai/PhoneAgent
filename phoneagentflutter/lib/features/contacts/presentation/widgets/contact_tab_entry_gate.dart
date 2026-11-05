import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/contact_entry_providers.dart';
import '../../../../app/contact_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../controller/contact_tab_entry_coordinator.dart';
import 'contact_permission_dialog.dart';

class ContactTabEntryGate extends ConsumerStatefulWidget {
  const ContactTabEntryGate({
    super.key,
    required this.builder,
    required this.onSelected,
    this.selected = 0,
    this.entryGeneration = 0,
    this.enabled = true,
  });
  final Widget Function(ValueChanged<int>) builder;
  final ValueChanged<int> onSelected;
  final int selected, entryGeneration;
  final bool enabled;
  @override
  ConsumerState<ContactTabEntryGate> createState() =>
      _ContactTabEntryGateState();
}

class _ContactTabEntryGateState extends ConsumerState<ContactTabEntryGate>
    with WidgetsBindingObserver {
  ContactTabEntryCoordinator? _coordinator;
  bool _showingDialog = false;
  bool get _active =>
      mounted && widget.enabled && ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_showingDialog && ModalRoute.of(context)?.isCurrent == false) {
      _coordinator?.cancel();
    }
  }

  @override
  void didUpdateWidget(ContactTabEntryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryGeneration != widget.entryGeneration ||
        !widget.enabled) {
      _coordinator?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !ref.read(contactsSharedFlowEnabledProvider)) {
      return;
    }
    if (_coordinator?.awaitingSettings == true) {
      _coordinator!.resumed();
    } else if (widget.selected == 1 && mounted && _coordinator?.busy != true) {
      ref.read(contactsControllerProvider.notifier).loadDevice();
    }
  }

  void _select(int tab) {
    if (!_active) return;
    if (tab != 1 || !ref.read(contactsSharedFlowEnabledProvider)) {
      _coordinator?.cancel();
      widget.onSelected(tab);
      return;
    }
    _coordinator ??= ContactTabEntryCoordinator(
      port: ref.read(contactAuthorizationPortProvider),
      isIOS: Theme.of(context).platform == TargetPlatform.iOS,
      isActive: () => _active,
      confirm: (kind) async {
        _showingDialog = true;
        try {
          return await showContactPermissionDialog(context, kind);
        } finally {
          _showingDialog = false;
        }
      },
      openSettings: () => ref.read(contactSettingsLauncherProvider)(),
      notice: (message) => showNativeNotice(context, message),
      enter: () {
        ref.read(contactsControllerProvider.notifier).loadDevice();
        widget.onSelected(1);
      },
    );
    _coordinator!.select();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginEpochProvider, (_, next) {
      _coordinator?.dispose();
      _coordinator = null;
    });
    return widget.builder(_select);
  }
}
