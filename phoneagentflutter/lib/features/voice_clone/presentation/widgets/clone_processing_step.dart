import 'package:flutter/material.dart';
import '../../domain/clone_enrollment.dart';
import '../controller/clone_enrollment_controller.dart';
import 'native_clone_controls.dart';

class CloneProcessingStep extends StatelessWidget {
  const CloneProcessingStep({super.key, required this.state});
  final CloneEnrollmentState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        switch (state.step) {
          CloneStep.collecting => '请按阿里云页面提示保持本人正脸并准确跟读',
          CloneStep.checking => '人脸与跟读采集已完成',
          _ => state.showSaveRecording ? '人脸与跟读认证已通过' : '正在读取或生成克隆音色',
        },
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: cloneTextSpacing(context, 12),
          height: 17 / 12,
          color: Color(0xFFB0B4C3),
        ),
      ),
      const SizedBox(height: 18),
      if (state.script.isNotEmpty && state.step != CloneStep.generating) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cloneCard(
            color: const Color(0xFFF8FAFC),
            border: const Color(0xFFE8ECF3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '请朗读以下内容：',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: cloneTextSpacing(context, 13),
                  color: cloneSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.script,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: cloneTextSpacing(context, 16),
                  height: 25 / 16,
                  fontWeight: FontWeight.w500,
                  color: cloneInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请使用正常语速，连续清晰地读完整句话；数字按中文读音读出，例如 7 读作“七”。',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: cloneTextSpacing(context, 12),
                  height: 18 / 12,
                  color: cloneSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: cloneCard(
          color: const Color(0xFFF8FAFC),
          border: const Color(0xFFE5E7EB),
        ),
        child: Column(
          children: [
            const _FaceGuide(),
            if (state.error.isEmpty) ...[
              const SizedBox(height: 14),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0A84FF),
                ),
              ),
            ],
            SizedBox(height: state.error.isEmpty ? 10 : 14),
            Text(
              state.error.isNotEmpty
                  ? state.error
                  : switch (state.step) {
                      CloneStep.collecting => '正在进行人脸与跟读采集，请按阿里云页面提示完成操作…',
                      CloneStep.checking => '采集已完成，正在核验认证结果并生成克隆音色，请稍候…',
                      _ => '正在使用本次跟读生成克隆音色，请稍候…',
                    },
              key: state.error.isNotEmpty
                  ? const ValueKey('clone-flow-error')
                  : null,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                letterSpacing: cloneTextSpacing(context, 13),
                height: 20 / 13,
                color: state.error.isEmpty
                    ? cloneSecondary
                    : const Color(0xFFE14D46),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Android's native explanatory frame, never a camera/recognition result.
class _FaceGuide extends StatelessWidget {
  const _FaceGuide();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 152,
      height: 188,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(76),
          bottom: Radius.circular(62),
        ),
        border: Border.all(width: 2, color: const Color(0xFFBFDBFE)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF6FF), Colors.white],
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF93C5FD), Color(0xFF2563EB)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 13,
                      left: 27,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xEBFFFFFF),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      left: 10,
                      child: Container(
                        width: 68,
                        height: 43,
                        decoration: const BoxDecoration(
                          color: Color(0xE0FFFFFF),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(34),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 115.52, height: 2, color: const Color(0x8C2563EB)),
          ],
        ),
      ),
    ),
  );
}
