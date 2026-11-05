import 'package:flutter/material.dart';

/// Presentation of the effective native Agent-requested file chooser.
class NativeAgentDocumentSheet extends StatelessWidget {
  const NativeAgentDocumentSheet({
    super.key,
    required this.title,
    required this.reason,
    required this.busy,
    required this.onChoose,
  });

  final String title, reason;
  final bool busy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF7FBFF), Color(0xFFEDF5FF)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDCEBFF)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title.trim().isEmpty ? '上传文件' : title.trim(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            if (reason.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reason.trim(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 14),
            Semantics(
              button: true,
              enabled: !busy,
              onTap: busy ? null : onChoose,
              label: '${busy ? '正在解析文件' : '点击选择文件'}，支持 Markdown、TXT',
              excludeSemantics: true,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(
                  foregroundPainter: const _DashedBorder(),
                  child: InkWell(
                    key: const ValueKey('agent-document-pick'),
                    onTap: busy ? null : onChoose,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 22,
                      ),
                      child: Column(
                        children: [
                          if (busy)
                            const SizedBox.square(
                              dimension: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0A84FF),
                              ),
                            )
                          else
                            const Icon(
                              Icons.folder,
                              size: 28,
                              color: Color(0xFFFFB020),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            busy ? '正在解析文件' : '点击选择文件',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '支持 Markdown、TXT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(15.25),
        ),
      );
    final paint = Paint()
      ..color = const Color(0xFFB7C7DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 12) {
        canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
