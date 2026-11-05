import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'shell_clone_ports.dart';

List<Override> shellCloneOverrides(
  ShellClonePorts ports, {
  bool formal = false,
}) => [
  cloneFlowPreviewProvider.overrideWithValue(!formal),
  cloneCreationPortProvider.overrideWithValue(ports),
  cloneVoiceRepositoryProvider.overrideWithValue(
    ShellCloneVoices(ports.catalog),
  ),
  cloneFlowProvider.overrideWith((ref, launch) {
    ref.watch(loginEpochProvider);
    final flow = PreviewCloneFlow()..hasRecording = ports.recording;
    ports.flows.add(flow);
    ref.onDispose(() => flow.current = false);
    return CloneFlowController(
      launch,
      CloneFlowServices(
        verification: flow.verification,
        candidates: flow.candidates,
        completion: flow,
        capture: () => flow.capture,
        player: flow,
        recordings: CloneFlowRecordings(
          read: flow.readRecording,
          save: (grant) async {
            await flow.save(grant);
            if (flow.current) ports.recording = true;
          },
          clear: () async {
            await flow.clear();
            if (flow.current) ports.recording = false;
          },
        ),
        points: ports.availablePoints,
        verifiedName: () async => '',
        identityPrefill: () async => CloneIdentityPrefill(
          name: ports.identity.value.name,
          verified: ports.identity.value.verificationStatus == 'VERIFIED',
        ),
        isCurrent: () => flow.current,
        onBilling: (candidate, confirmed) {
          if (!flow.current) return;
          ports.verificationPassed(flow);
          if (confirmed) {
            ports.catalog.cloneAssets.add(candidate.modelId);
            ports.catalog.cloneModes.add(candidate.modelId);
          }
        },
      ),
    );
  }),
];
