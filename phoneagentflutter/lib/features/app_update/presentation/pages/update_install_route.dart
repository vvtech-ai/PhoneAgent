import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/update_install_providers.dart';
import 'update_install_page.dart';

class UpdateInstallRoute extends ConsumerStatefulWidget {
  const UpdateInstallRoute({
    super.key,
    required this.launch,
    this.onRefresh,
    this.dialog = false,
    this.autoStart = false,
  });
  final UpdateInstallLaunch launch;
  final VoidCallback? onRefresh;
  final bool dialog, autoStart;
  @override
  ConsumerState<UpdateInstallRoute> createState() => _UpdateInstallRouteState();
}

class _UpdateInstallRouteState extends ConsumerState<UpdateInstallRoute> {
  late final _owner = ref.read(loginEpochProvider);
  @override
  Widget build(BuildContext context) {
    if (_owner != ref.watch(loginEpochProvider)) {
      return Scaffold(
        appBar: NativePageAppBar(
          title: '会话已变化',
          textScaler: MediaQuery.textScalerOf(context),
        ),
        body: const Center(child: Text('请返回后重新进入')),
      );
    }
    ref.watch(updateInstallProvider(widget.launch));
    return UpdateInstallPage(
      controller: ref.read(updateInstallProvider(widget.launch).notifier),
      onRefresh: widget.onRefresh,
      dialog: widget.dialog,
      autoStart: widget.autoStart,
    );
  }
}
