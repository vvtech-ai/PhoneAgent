import 'package:flutter/material.dart';
import '../../data/preview_clone_flow.dart';
import '../../domain/clone_creation.dart';
import '../controller/clone_flow_controller.dart';
import '../controller/clone_flow_services.dart';
import 'clone_flow_page.dart';

class CloneFlowPreviewPage extends StatefulWidget {
  const CloneFlowPreviewPage({super.key, required this.scenario});
  final CloneFlowScenario scenario;
  @override
  State<CloneFlowPreviewPage> createState() => _CloneFlowPreviewPageState();
}

class _CloneFlowPreviewPageState extends State<CloneFlowPreviewPage> {
  late final _ports = PreviewCloneFlow(widget.scenario);
  late final _controller = CloneFlowController(
    CloneCreationLaunch(
      const CloneCreationModel(
        pricePoints: 300,
        id: PreviewCloneFlow.model,
        name: '千问 Omni Plus',
      ),
      widget.scenario == CloneFlowScenario.expiredRecording
          ? CloneCreationStart.savedRecording
          : CloneCreationStart.authentication,
    ),
    CloneFlowServices(
      verification: _ports.verification,
      candidates: _ports.candidates,
      completion: _ports,
      capture: () => _ports.capture,
      player: _ports,
      recordings: CloneFlowRecordings(
        read: _ports.readRecording,
        save: _ports.save,
        clear: _ports.clear,
      ),
      points: () async => _ports.points,
      verifiedName: () async => _ports.verifiedName,
      isCurrent: () => _ports.current,
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CloneFlowPage(controller: _controller, preview: true);
}
