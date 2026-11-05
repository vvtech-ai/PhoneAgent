import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/memory_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../domain/account_memory.dart';
import '../widgets/memory_confirmation.dart';
import '../widgets/memory_frame.dart';
import '../widgets/memory_overview.dart';
import 'memory_editor_page.dart';

class MemorySettingsPage extends ConsumerStatefulWidget {
  const MemorySettingsPage({super.key, this.list = false});
  final bool list;
  @override
  ConsumerState<MemorySettingsPage> createState() => _MemorySettingsPageState();
}

class _MemorySettingsPageState extends ConsumerState<MemorySettingsPage> {
  int? _epoch;
  @override
  void initState() {
    super.initState();
    _epoch = ref.read(loginEpochProvider);
  }

  void _push(Widget page) {
    ref.read(memoryControllerProvider.notifier).clearFailure();
    final container = ProviderScope.containerOf(context);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteProviderScope(container: container, child: page),
      ),
    );
  }

  Future<void> _apply(MemoryAction? action) async {
    final controller = ref.read(memoryControllerProvider.notifier);
    if (action == null) {
      await controller.retry();
    } else {
      await controller.apply(action);
    }
    if (!mounted || ref.read(loginEpochProvider) != _epoch) return;
    final state = ref.read(memoryControllerProvider);
    if (state.notice.isNotEmpty) showNativeNotice(context, state.notice);
  }

  Future<void> _clear() async {
    if (!await confirmMemoryDeletion(context, all: true)) return;
    if (!mounted || ref.read(loginEpochProvider) != _epoch) return;
    await _apply(const MemoryAction('CLEAR'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryControllerProvider);
    final snapshot = state.snapshot;
    final controller = ref.read(memoryControllerProvider.notifier);
    ref.listen(loginEpochProvider, (_, epoch) {
      if (epoch != _epoch) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) Future.microtask(controller.clearFailure);
      },
      child: MemoryFrame(
        title: widget.list ? '记忆内容' : '记忆',
        busy: state.busy,
        error: state.error,
        retryLabel: state.refreshable ? '刷新' : '重试',
        onRetry: state.retryable || state.refreshable
            ? () => _apply(null)
            : null,
        action: widget.list
            ? PopupMenuButton<String>(
                tooltip: '更多操作',
                enabled: !state.busy && snapshot != null,
                icon: const Icon(Icons.more_horiz, color: MemoryColors.text),
                onSelected: (_) => _clear(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'clear',
                    enabled: snapshot?.entries.isNotEmpty ?? false,
                    child: Text(
                      '删除全部记忆',
                      style: TextStyle(
                        color: snapshot?.entries.isNotEmpty == true
                            ? MemoryColors.red
                            : MemoryColors.secondary,
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: state.busy && snapshot == null
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: MemoryColors.blue),
                ),
              )
            : snapshot == null
            ? const SizedBox()
            : MemoryOverview(
                snapshot: snapshot,
                list: widget.list,
                busy: state.busy,
                onEnabled: (value) =>
                    _apply(MemoryAction('SET_ENABLED', enabled: value)),
                onList: () => _push(const MemorySettingsPage(list: true)),
                onAdd: () => _push(const MemoryEditorPage()),
                onEdit: (entry) => _push(MemoryEditorPage(entry: entry)),
              ),
      ),
    );
  }
}
