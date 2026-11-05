import 'package:flutter/material.dart';
import '../../../conversation/presentation/controller/conversation_controller.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import '../../../conversation/presentation/pages/conversation_page.dart';
import '../../data/preview_ocr.dart';
import '../../data/preview_ocr_session.dart';
import '../controller/ocr_session_controller.dart';
import '../widgets/conversation_ocr_host.dart';

/// Isolated ports, but the same session controller, command, history and cards.
class OcrPreviewPage extends StatefulWidget {
  const OcrPreviewPage({super.key});
  @override
  State<OcrPreviewPage> createState() => _OcrPreviewPageState();
}

class _OcrPreviewPageState extends State<OcrPreviewPage> {
  final _port = PreviewOcrSession();
  late ConversationController _conversation;
  late ConversationState _state;
  late void Function() _unsubscribe;
  int _nextId = 0;
  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create({bool restore = false}) {
    late final ConversationController conversation;
    final ocr = OcrSessionController(
      sessionId: PreviewOcrSession.sessionId,
      source: _port,
      recognizer: _port,
      repository: _port,
      nextId: () => '${++_nextId}',
      isCurrent: () => conversation.isOpen,
      initialOpening: () => conversation.pendingInitialOpening,
    );
    conversation = ConversationController(
      entry: ConversationEntry(
        sessionId: PreviewOcrSession.sessionId,
        restore: restore,
        opening: '添加图片后查看识别结果，再继续文字输入。',
      ),
      accountId: 'isolated-mock',
      gateway: _port,
      history: _port,
      attachments: ocr,
      nextId: () => 'mock-command-${++_nextId}',
    );
    _conversation = conversation;
    _unsubscribe = conversation.addListener((state) {
      _state = state;
      if (mounted) setState(() {});
    });
    if (restore) conversation.restore();
  }

  @override
  void dispose() {
    _unsubscribe();
    _conversation.dispose();
    super.dispose();
  }

  void _restore() {
    _unsubscribe();
    _conversation.dispose();
    _create(restore: true);
  }

  Future<void> _pick() async {
    final ocr = _conversation.attachments!;
    if (ocr.snapshot.busy || !_state.canSend) {
      _conversation.showNotice('附件处理中，请稍后添加');
      return;
    }
    final scenario = await showModalBottomSheet<OcrPreviewScenario>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('MOCK · 选择合成图片场景'),
              ),
              for (final entry in const {
                OcrPreviewScenario.contact: '合成名片',
                OcrPreviewScenario.meeting: '合成会议海报（长文字）',
                OcrPreviewScenario.emptyText: '未识别到文字',
                OcrPreviewScenario.recognition: '本地识别失败',
                OcrPreviewScenario.refinement: 'AI整理失败',
                OcrPreviewScenario.cloudCommit: '云端保存失败',
              }.entries)
                ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(sheet, entry.key),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('取消选择'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || scenario == null || !_conversation.isOpen) return;
    _port.nextScenario = scenario;
    await ocr.pick(
      _conversation.ocrBoundary.sourceAnchor,
      currentAnchor: () => _conversation.ocrBoundary.sourceAnchor,
    );
    if (_conversation.isOpen && ocr.snapshot.notice.isNotEmpty) {
      _conversation.showNotice(ocr.snapshot.notice);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          MaterialBanner(
            content: const Text('MOCK · 图片识别演练，不读取私人图片、不上传、不影响原对话。'),
            actions: [
              TextButton(onPressed: _restore, child: const Text('恢复本次演练历史')),
            ],
          ),
          Expanded(
            child: ConversationOcrHost(
              controller: _conversation.attachments,
              boundary: _conversation.ocrBoundary,
              builder: (attachments) => ConversationPage(
                state: _state,
                modelName: 'MOCK',
                attachments: attachments,
                onClose: () => Navigator.pop(context),
                onToggle: _conversation.toggleInput,
                onSend: _conversation.send,
                onChoose: _conversation.choose,
                onRetry: _conversation.restore,
                onNotice: _conversation.showNotice,
                onModels: () => _conversation.showNotice('演练不修改通话模型'),
                onAttachments: _pick,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
