import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_enrollment_steps.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_flow_header.dart';

/// Actual consent presentation with empty agreement/authentication actions.
class FlutterCloneConsentReference extends StatelessWidget {
  const FlutterCloneConsentReference({super.key, required this.scene});
  final String scene;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            CloneFlowHeader(step: CloneStep.consent, onBack: () {}),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  CloneConsentStep(
                    state: CloneEnrollmentState(
                      agreed: scene != 'clone-consent',
                      busy: scene == 'clone-consent-busy',
                    ),
                    onAgree: (_) {},
                    onNext: () {},
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
