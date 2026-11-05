import 'package:flutter/material.dart';
import '../../domain/user_document_presentation.dart';

class NativeDocumentCard extends StatelessWidget {
  const NativeDocumentCard({
    super.key,
    required this.files,
    this.parsing = false,
  });
  final List<UserDocumentFile> files;
  final bool parsing;
  // Compose body1 tracks in sp; Flutter does not scale tracking implicitly.
  double _tracking(BuildContext context, double size) =>
      .5 * MediaQuery.textScalerOf(context).scale(size) / size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 308),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E9F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: Text(
                      parsing ? '正在上传任务资料' : '已上传任务资料',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: _tracking(context, 14),
                        height: 19 / 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2633),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: Text(
                      '${files.length} 个文件',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: _tracking(context, 11),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF596579),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                for (final (index, file) in files.indexed) ...[
                  if (index > 0) const SizedBox(height: 10),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x170A84FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '文',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: _tracking(context, 13),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0877D1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: _tracking(context, 12),
                                height: 16 / 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF202938),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              file.metadata,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: _tracking(context, 11),
                                height: 15 / 11,
                                color: const Color(0xFF596579),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
