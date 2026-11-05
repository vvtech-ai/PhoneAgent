import 'package:flutter/material.dart';

class NativeTaskRatingEntry extends StatelessWidget {
  const NativeTaskRatingEntry({
    super.key,
    required this.readOnly,
    required this.onOpen,
    this.rewardHint,
    this.grantedPoints,
  });
  final bool readOnly;
  final VoidCallback onOpen;
  final String? rewardHint;
  final int? grantedPoints;
  @override
  Widget build(BuildContext context) {
    final action = readOnly ? '查看' : '去评分';
    final message = readOnly
        ? (grantedPoints != null && grantedPoints! > 0
              ? '评价已提交，已获得$grantedPoints积分。'
              : '评价已提交')
        : '为本次任务评分${rewardHint == null ? '' : '，${rewardHint!.replaceFirst('提交后', '')}。'}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          container: true,
          button: true,
          label: '$message，$action',
          onTap: onOpen,
          excludeSemantics: true,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFCFE4FF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star,
                        size: 22,
                        color: Color(0xFF1687F8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14213D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1687F8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
