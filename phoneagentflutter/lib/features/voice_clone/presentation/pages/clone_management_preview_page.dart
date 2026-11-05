import 'package:flutter/material.dart';
import '../../data/preview_clone_management_repository.dart';
import '../../../call_models/presentation/controller/call_model_controller.dart';
import '../../../call_models/presentation/pages/call_models_page.dart';
import '../../../call_models/presentation/pages/call_voices_page.dart';
import '../../../call_models/domain/call_models.dart';

class CloneManagementPreviewPage extends StatefulWidget {
  const CloneManagementPreviewPage({
    super.key,
    this.failFirstDelete = false,
    this.failReadAfterDelete = false,
  });
  final bool failFirstDelete, failReadAfterDelete;
  @override
  State<CloneManagementPreviewPage> createState() =>
      _CloneManagementPreviewPageState();
}

class _CloneManagementPreviewPageState
    extends State<CloneManagementPreviewPage> {
  late final _repository = PreviewCloneManagementRepository(
    failFirstDelete: widget.failFirstDelete,
    failReadAfterDelete: widget.failReadAfterDelete,
  );
  late final _controller = CallModelController(
    _repository,
    cloneRepository: PreviewCloneManagementPort(_repository),
  );
  late final void Function() _remove;
  CallModelState _state = const CallModelState();
  bool _voices = false;
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((value) {
      if (mounted) setState(() => _state = value);
    }, fireImmediately: false);
    _controller.load();
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  void _back() {
    if (_voices) {
      setState(() => _voices = false);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _open(CallModel model) async {
    if (!await _controller.select(model) || !mounted) return;
    setState(() => _voices = true);
    await _controller.loadVoices(model.id);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_voices,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('MOCK · 两模型内存演练；不删除真实音色、身份或录音'),
            ),
            Expanded(
              child: _voices
                  ? CallVoicesPage(
                      state: _state,
                      onBack: _back,
                      onRetry: () =>
                          _controller.loadVoices(_state.voiceProvider!),
                      onSelect: _controller.selectVoice,
                      onSelectClone: _controller.selectClone,
                      onDeleteClone: _controller.deleteClone,
                    )
                  : CallModelsPage(
                      state: _state,
                      onBack: _back,
                      onRetry: _controller.load,
                      onSelect: _controller.select,
                      onVoices: _open,
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
