import 'package:flutter/material.dart';

class NativeTaskRatingSuccess extends StatelessWidget {
  const NativeTaskRatingSuccess({
    super.key,
    required this.grantedPoints,
    required this.onDismiss,
  });

  final int? grantedPoints;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.bottomCenter,
    insetPadding: EdgeInsets.zero,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: '关闭',
                    onTap: onDismiss,
                    excludeSemantics: true,
                    child: IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF65758B),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 30,
                    color: Color(0xFF1687F8),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '评价提交成功',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14213D),
                  ),
                ),
                if (grantedPoints != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '已获得$grantedPoints积分',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1687F8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '积分已发放，本任务不可重复领取。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF7A8494)),
                  ),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onDismiss,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1687F8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
