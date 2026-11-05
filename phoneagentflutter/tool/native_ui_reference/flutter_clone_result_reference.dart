import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_candidate_step.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_flow_header.dart';

/// Effective result presentation only; no service or audio port is constructed.
class FlutterCloneResultReference extends StatelessWidget {
  const FlutterCloneResultReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    body: SafeArea(
      child: Column(
        children: [
          CloneFlowHeader(
            step: CloneStep.candidate,
            onBack: scene == 'clone-result-busy' ? null : () {},
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                CloneCandidateStep(
                  state: CloneEnrollmentState(
                    step: CloneStep.candidate,
                    busy: scene == 'clone-result-busy',
                    playing: scene == 'clone-result-playing',
                    error: scene == 'clone-result-error' ? '合成试听失败，请稍后重试' : '',
                  ),
                  onSave: (_) {},
                  onPreview: () {},
                  onConfirm: () {},
                  onRerecord: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
