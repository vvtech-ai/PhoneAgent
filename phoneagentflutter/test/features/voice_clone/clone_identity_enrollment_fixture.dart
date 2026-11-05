import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';

CloneFlowController identityFlow(
  PreviewCloneFlow ports, {
  bool verified = true,
  String masked = '000***********0005',
  Future<bool> Function()? reset,
}) => CloneFlowController(
  CloneCreationLaunch(
    const CloneCreationModel(
      id: PreviewCloneFlow.model,
      name: '合成模型',
      pricePoints: 300,
    ),
    CloneCreationStart.authentication,
  ),
  CloneFlowServices(
    verification: ports.verification,
    candidates: ports.candidates,
    completion: ports,
    capture: () => ports.capture,
    player: ports,
    recordings: CloneFlowRecordings(
      read: ports.readRecording,
      save: ports.save,
      clear: ports.clear,
    ),
    points: () async => ports.points,
    verifiedName: () async => '',
    identityPrefill: () async => CloneIdentityPrefill(
      name: '演练用户',
      verified: verified,
      certNoMasked: masked,
    ),
    resetIdentity: reset,
    isCurrent: () => ports.current,
  ),
);
