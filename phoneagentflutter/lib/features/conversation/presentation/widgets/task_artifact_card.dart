import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/task_artifact_providers.dart';
import '../../domain/artifacts/task_artifact.dart';
import '../../domain/artifacts/task_artifact_download.dart';

class TaskArtifactCard extends ConsumerWidget {
  const TaskArtifactCard({
    super.key,
    required this.artifact,
    required this.owner,
  });
  final TaskArtifact artifact;
  final Object owner;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(taskArtifactDownloadProvider(owner));
    final state = controller.state(artifact.id);
    final csv = artifact.kind == TaskArtifactKind.batchCsv;
    final saved = state.phase == ArtifactDownloadPhase.saved;
    final busy = state.phase == ArtifactDownloadPhase.downloading;
    final enabled = artifact.ready && !busy;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEDFAF0), Color(0xFFD6F5DC)],
          ),
          border: Border.all(color: const Color(0x3334C759)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              csv ? '批量外呼回执' : '任务模板',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _SummaryRow('文件', artifact.fileName, maxLines: 2),
            const SizedBox(height: 10),
            _SummaryRow(
              '类型',
              csv
                  ? (artifact.itemCount == null
                        ? 'CSV 文件'
                        : '${artifact.itemCount} 条回执')
                  : 'Word 文档',
            ),
            if (!artifact.ready) Text('文件状态：${artifact.status}'),
            if (state.notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  state.notice,
                  style: TextStyle(
                    fontSize: 12,
                    color: state.phase == ArtifactDownloadPhase.failed
                        ? const Color(0xFFD70015)
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled
                      ? const [Color(0xFF34C759), Color(0xFF28A745)]
                      : const [Color(0xFFEEF2F7), Color(0xFFE8EDF5)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF9CA7B5),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: !enabled
                    ? null
                    : () => unawaited(
                        saved
                            ? controller.open(artifact.id)
                            : controller.download(artifact),
                      ),
                child: Text(
                  busy
                      ? '下载中'
                      : saved
                      ? '查看'
                      : state.phase == ArtifactDownloadPhase.failed
                      ? '重试'
                      : csv
                      ? '下载回执'
                      : '下载模板',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.maxLines = 1});
  final String label, value;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 42,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
      ),
      Expanded(
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF344054)),
        ),
      ),
    ],
  );
}
