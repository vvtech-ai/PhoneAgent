import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/commerce_providers.dart';
import '../widgets/clone_entry_membership_gate.dart';
import '../../../../app/clone_flow_providers.dart';
import '../../../commerce/presentation/pages/membership_route.dart';
import '../../domain/clone_creation.dart';
import '../widgets/clone_creation_sheet.dart';
import 'clone_flow_page.dart';

Future<void> openCloneCreation(
  BuildContext context, {
  VoidCallback? onFlowStarted,
  String? targetModelId,
  ValueChanged<String>? onModelStarted,
}) => Navigator.of(context).push<void>(
  PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => CloneCreationRoute(
      onFlowStarted: onFlowStarted,
      targetModelId: targetModelId,
      onModelStarted: onModelStarted,
    ),
  ),
);

class CloneCreationRoute extends ConsumerStatefulWidget {
  const CloneCreationRoute({
    super.key,
    this.onFlowStarted,
    this.targetModelId,
    this.onModelStarted,
  });
  final String? targetModelId;
  final ValueChanged<String>? onModelStarted;
  final VoidCallback? onFlowStarted;
  @override
  ConsumerState<CloneCreationRoute> createState() => _CloneCreationRouteState();
}

class _CloneCreationRouteState extends ConsumerState<CloneCreationRoute> {
  CloneCreationLaunch? _launch;
  late final int? _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(loginEpochProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _select());
  }

  Future<void> _select({String initialError = ''}) async {
    if (!mounted || _owner != ref.read(loginEpochProvider)) return;
    final allowed = await checkCloneEntryMembership(
      context,
      load: ref.read(commerceRepositoryProvider).membership,
      loadCatalog: ref.read(commerceRepositoryProvider).catalog,
      isCurrent: () => mounted && _owner == ref.read(loginEpochProvider),
      upgrade: _upgrade,
    );
    if (!mounted) return;
    if (!allowed) {
      Navigator.pop(context);
      return;
    }
    final launch = await showCloneCreationSheet(
      context,
      ref.read(cloneCreationPortProvider),
      initialError: initialError,
      targetModelId: widget.targetModelId,
      isCurrent: () => mounted && _owner == ref.read(loginEpochProvider),
      onUpgrade: _upgrade,
    );
    if (!mounted) return;
    if (launch == null || _owner != ref.read(loginEpochProvider)) {
      Navigator.pop(context);
    } else {
      widget.onFlowStarted?.call();
      widget.onModelStarted?.call(launch.model.id);
      setState(() => _launch = launch);
    }
  }

  Future<void> _upgrade() async {
    if (!mounted || _owner != ref.read(loginEpochProvider)) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const MembershipRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final epoch = ref.watch(loginEpochProvider);
    ref.watch(cloneCreationPortProvider);
    if (epoch != _owner) {
      return Scaffold(
        appBar: const NativePageAppBar(title: '会话已变化'),
        body: const Center(child: Text('请返回后重新进入')),
      );
    }
    final launch = _launch;
    if (launch == null) {
      return const Material(
        type: MaterialType.transparency,
        child: SizedBox.expand(),
      );
    }
    ref.watch(cloneFlowProvider(launch));
    return CloneFlowPage(
      key: ObjectKey(launch),
      preview: ref.watch(cloneFlowPreviewProvider),
      onCreationFailed: (launch.start != CloneCreationStart.authentication)
          ? (message) {
              setState(() => _launch = null);
              _select(initialError: message);
            }
          : null,
      controller: ref.read(cloneFlowProvider(launch).notifier),
    );
  }
}
