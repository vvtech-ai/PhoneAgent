import '../../../../core/design/native_action_style.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/attachment_tokens.dart';
import '../../domain/document_import.dart';
import '../controller/document_import_controller.dart';

class DocumentImportSheet extends StatefulWidget {
  const DocumentImportSheet({
    super.key,
    required this.controller,
    required this.onReady,
    this.preview = false,
  });
  final DocumentImportController controller;
  final bool Function(DocumentTurn) onReady;
  final bool preview;
  @override
  State<DocumentImportSheet> createState() => _DocumentImportSheetState();
}

class _DocumentImportSheetState extends State<DocumentImportSheet> {
  late final void Function() _unsubscribe;
  bool _submissionRejected = false;
  @override
  void initState() {
    super.initState();
    _unsubscribe = widget.controller.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _unsubscribe();
    widget.controller.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _pick() async {
    setState(() => _submissionRejected = false);
    final result = await widget.controller.choose();
    if (!mounted) return;
    if (result != null && !widget.preview) {
      final accepted = widget.onReady(result);
      if (accepted) {
        Navigator.pop(context);
      } else {
        setState(() => _submissionRejected = true);
      }
    } else if (result == null &&
        widget.controller.snapshot.phase == DocumentImportPhase.idle) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.snapshot;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: AttachmentTokens.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.preview ? 'MOCK · 文档导入' : '导入文档',
                    style: AttachmentTokens.heading,
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: '关闭文档导入',
                    onTap: _close,
                    excludeSemantics: true,
                    child: IconButton(
                      tooltip: '关闭文档导入',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              widget.preview
                  ? '仅合成文件与内存解析，不读取或上传真实资料。'
                  : '仅支持 .docx / .xlsx，单个文件最大 5MB。选择后上传至当前环境解析并继续对话。',
              style: AttachmentTokens.subtitle,
            ),
            const SizedBox(height: 14),
            if (state.busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                state.phase == DocumentImportPhase.picking
                    ? '等待选择文件'
                    : '正在解析文件 ${state.completed}/${state.files.length}',
              ),
            ],
            for (final name in state.turn == null ? state.files : <String>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(name),
              ),
            if (state.message.isNotEmpty)
              Text(
                state.message,
                key: const ValueKey('document-error'),
                style: const TextStyle(color: Colors.red),
              ),
            if (_submissionRejected)
              const Text(
                '对话状态已变化，文档未发送。请关闭窗口后重试。',
                style: TextStyle(color: Colors.red),
              ),
            if (state.turn != null) ...[
              Text(
                state.turn!.display,
                key: const ValueKey('document-summary'),
              ),
              if (widget.preview)
                const Text('MOCK：整批解析成功，已生成文档轮次；未提交真实 Agent。'),
            ],
            const SizedBox(height: 12),
            if (state.phase != DocumentImportPhase.ready)
              NativeActionSurface(
                child: FilledButton(
                  key: const ValueKey('pick-documents'),
                  onPressed: state.busy ? null : _pick,
                  child: Text(
                    state.phase == DocumentImportPhase.failed
                        ? '重新选择文件'
                        : '选择文件',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
