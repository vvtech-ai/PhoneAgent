import 'package:flutter/material.dart';
import '../controller/clone_enrollment_controller.dart';
import 'native_clone_controls.dart';

class CloneCandidateStep extends StatelessWidget {
  const CloneCandidateStep({
    super.key,
    required this.state,
    required this.onSave,
    required this.onPreview,
    required this.onConfirm,
    required this.onRerecord,
    this.ready = true,
    this.canRerecord = true,
  });
  final CloneEnrollmentState state;
  final bool ready, canRerecord;
  final ValueChanged<bool> onSave;
  final VoidCallback onPreview, onConfirm, onRerecord;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ready ? '声音克隆已完成' : '正在生成克隆音色',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF171A24),
              ),
            ),
            const SizedBox(height: 14),
            if (state.showSaveRecording) ...[
              CloneCheckRow(
                key: const Key('clone-save-recording'),
                result: true,
                checked: state.saveRecording,
                onChanged: state.busy ? null : onSave,
                label: '保存本次认证的录音，用于下一次声音克隆时不再重新认证。如果已有保存过的录音，将被替换',
              ),
              const SizedBox(height: 12),
            ],
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.only(left: 12, right: 4),
              decoration: cloneCard(radius: 9, border: const Color(0xFFE4E9F1)),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '试听',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF171A24),
                      ),
                    ),
                  ),
                  Semantics(
                    container: true,
                    label: state.previewLoading
                        ? '正在读取试听'
                        : state.playing
                        ? '停止试听'
                        : '开始试听',
                    button: true,
                    enabled: ready && !state.busy,
                    onTap: !ready || state.busy ? null : onPreview,
                    excludeSemantics: true,
                    child: IconButton(
                      key: const Key('clone-preview'),
                      onPressed: !ready || state.busy ? null : onPreview,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !ready || state.busy
                              ? const Color(0xFFF2F4F7)
                              : const Color(0xFFEEF6FF),
                        ),
                        child: state.previewLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : CustomPaint(
                                size: Size.square(
                                  (state.playing ? 7 : 9) *
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(state.playing ? 12 : 15) /
                                      (state.playing ? 12 : 15),
                                ),
                                painter: _PreviewGlyph(
                                  playing: state.playing,
                                  color: !ready || state.busy
                                      ? const Color(0xFFAAB3C1)
                                      : const Color(0xFF1488F5),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClonePrimaryAction(
              result: true,
              label: state.busy ? '确认中…' : '设为默认声音',
              loading: state.busy,
              onPressed: !ready || state.busy ? null : onConfirm,
            ),
            TextButton(
              onPressed: state.busy || !canRerecord ? null : onRerecord,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: const Color(0xFF1488F5),
                disabledForegroundColor: const Color(0x801488F5),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('重新录制'),
            ),
            if (state.error.isNotEmpty)
              Text(
                state.error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 17 / 12,
                  color: Color(0xFFE14D46),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// A monochrome glyph avoids Flutter's emoji fallback for U+25B6, even with VS15.
class _PreviewGlyph extends CustomPainter {
  const _PreviewGlyph({required this.playing, required this.color});
  final bool playing;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (playing) {
      canvas.drawRect(Offset.zero & size, paint);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewGlyph oldDelegate) =>
      playing != oldDelegate.playing || color != oldDelegate.color;
}
