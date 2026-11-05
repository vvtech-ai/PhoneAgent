import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_enrollment_steps.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_flow_header.dart';

/// Actual identity fields with empty authentication action.
class FlutterCloneIdentityReference extends StatelessWidget {
  const FlutterCloneIdentityReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            CloneFlowHeader(step: CloneStep.identity, onBack: () {}),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  CloneIdentityStep(
                    busy: false,
                    error: scene == 'clone-identity-error' ? '合成填写失败' : '',
                    verifiedName: scene == 'clone-identity-verified'
                        ? '演练用户'
                        : '',
                    onSubmit: (_, _) {},
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
