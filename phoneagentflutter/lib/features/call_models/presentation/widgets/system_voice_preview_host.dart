import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/system_voice_preview_providers.dart';
import '../controller/system_voice_preview_controller.dart';

class SystemVoicePreviewHost extends ConsumerStatefulWidget {
  const SystemVoicePreviewHost({
    super.key,
    required this.builder,
    this.modelId = '',
  });
  final String modelId;
  final Widget Function(
    SystemVoicePreviewState,
    ValueChanged<String>,
    Future<bool> Function(),
  )
  builder;
  @override
  ConsumerState<SystemVoicePreviewHost> createState() =>
      _SystemVoicePreviewHostState();
}

class _SystemVoicePreviewHostState extends ConsumerState<SystemVoicePreviewHost>
    with WidgetsBindingObserver {
  final _owner = Object();
  SystemVoicePreviewController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant SystemVoicePreviewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelId != widget.modelId) {
      unawaited(_controller?.stop());
      _controller = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller?.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop immediately; the autoDispose owner then closes the player.
    unawaited(_controller?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = systemVoicePreviewProvider((
      owner: _owner,
      modelId: widget.modelId,
    ));
    final state = ref.watch(provider);
    _controller = ref.read(provider.notifier);
    return widget.builder(
      state,
      (id) => unawaited(_controller!.toggle(id)),
      () => _controller!.stop(),
    );
  }
}
