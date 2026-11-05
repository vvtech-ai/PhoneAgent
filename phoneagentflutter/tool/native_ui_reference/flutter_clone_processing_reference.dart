import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_processing_step.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_flow_header.dart';

/// Actual processing presentation without any authentication port.
class FlutterCloneProcessingReference extends StatelessWidget {
  const FlutterCloneProcessingReference({super.key, required this.scene});
  final String scene;
  CloneStep get step => switch (scene) {
    'clone-collecting' => CloneStep.collecting,
    'clone-generating' => CloneStep.generating,
    _ => CloneStep.checking,
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            CloneFlowHeader(step: step, onBack: () {}),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  CloneProcessingStep(
                    state: CloneEnrollmentState(
                      step: step,
                      busy: scene != 'clone-processing-error',
                      script: '合成演练，请在七点通知会议。',
                      error: scene == 'clone-processing-error'
                          ? '合成认证结果暂未确认'
                          : '',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
