import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/identity_providers.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_notice.dart';
import '../controller/identity_controller.dart';
import '../widgets/identity_widgets.dart';
import '../../../voice_clone/presentation/pages/clone_creation_route.dart';
import 'identity_page.dart';

enum IdentityDestination { models }

class IdentityRoute extends ConsumerStatefulWidget {
  const IdentityRoute({super.key, this.onCreateClone});
  final Future<void> Function(BuildContext)? onCreateClone;
  @override
  ConsumerState<IdentityRoute> createState() => _IdentityRouteState();
}

class _IdentityRouteState extends ConsumerState<IdentityRoute> {
  bool _deleteDialog = false;
  bool _openingClone = false;
  Future<void> _createClone() async {
    if (_openingClone || ref.read(identityControllerProvider).busy) return;
    _openingClone = true;
    try {
      await (widget.onCreateClone ?? openCloneCreation)(context);
    } finally {
      _openingClone = false;
    }
  }

  Future<void> _save() async {
    final result = await ref.read(identityControllerProvider.notifier).save();
    if (!mounted || result == IdentityOutcome.rejected) return;
    showNativeNotice(context, '身份资料已保存');
    if (result == IdentityOutcome.savedReturn) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (_deleteDialog || ref.read(identityControllerProvider).busy) return;
    _deleteDialog = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8A000000),
      builder: (_) => const IdentityDeleteDialog(),
    );
    _deleteDialog = false;
    if (!mounted || confirmed != true) return;
    final result = await ref
        .read(identityControllerProvider.notifier)
        .delete(confirmed: true);
    if (!mounted || result != IdentityOutcome.deleted) return;
    if (!ref.read(identityControllerProvider).cleanupPending) {
      showNativeNotice(context, '身份已删除，已切换为默认音色');
    }
  }

  Future<void> _retryCleanup() async {
    final controller = ref.read(identityControllerProvider.notifier);
    if (!ref.read(identityControllerProvider).cleanupPending) return;
    await controller.retryCleanup();
    if (mounted && !ref.read(identityControllerProvider).cleanupPending) {
      showNativeNotice(context, '身份已删除，已切换为默认音色');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityControllerProvider);
    final controller = ref.read(identityControllerProvider.notifier);
    return PopScope<IdentityDestination>(
      canPop: !state.mutating && !state.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.mutating && state.editing) {
          controller.cancelEdit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NativePageBackground(
          child: SafeArea(
            child: IdentityPage(
              state: state,
              actions: IdentityActions(
                back: () => Navigator.pop(context),
                retry: controller.load,
                retryCleanup: _retryCleanup,
                edit: controller.beginEdit,
                cancel: controller.cancelEdit,
                save: _save,
                delete: _delete,
                models: _createClone,
                name: (value) => controller.edit(name: value),
                phone: (value) => controller.edit(phone: value),
                gender: (value) => controller.edit(gender: value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
