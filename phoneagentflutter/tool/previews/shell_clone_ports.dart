import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'shell_catalog_fakes.dart';

/// Shared synthetic server state, scoped to a single complete-App workbench.
class ShellClonePorts implements CloneCreationPort {
  ShellClonePorts(this.identity, this.catalog);
  final PreviewIdentityCleanup identity;
  final FakeCallModelRepository catalog;
  final flows = <PreviewCloneFlow>[];
  bool recording = false;
  static const prices = {'QWEN_OMNI_PLUS': 650, 'DOUBAO_SEEDUPLEX_3_0': 900};
  static const names = {
    'QWEN_OMNI_PLUS': 'QwenOmniPlus',
    'DOUBAO_SEEDUPLEX_3_0': 'Seeduplex V3',
  };
  @override
  Future<List<CloneCreationModel>> models() async => [
    for (final entry in names.entries)
      CloneCreationModel(
        cloneEntitled: true,
        pricePoints: prices[entry.key],
        id: entry.key,
        name: entry.value,
        currentReady: catalog.cloneAssets.contains(entry.key),
      ),
  ];
  @override
  Future<int> availablePoints() async => 900;
  @override
  Future<bool> hasValidRecording() async => recording;

  void verificationPassed(PreviewCloneFlow flow) {
    final verified = flow.verification.lastIdentity;
    if (verified == null) return;
    final previous = identity.value;
    // Never store the supplied identity number, even in synthetic state.
    identity.value = IdentityProfile(
      accountId: previous.accountId,
      name: verified.name,
      gender: previous.gender,
      contactPhone: previous.contactPhone,
      verificationStatus: 'VERIFIED',
    );
  }

  void clearIdentityAssets() {
    recording = false;
    catalog.cloneAssets.clear();
    catalog.cloneModes.clear();
  }
}

class ShellCloneVoices implements CloneVoiceRepository, CloneVoiceDeletionPort {
  ShellCloneVoices(this.catalog);
  final FakeCallModelRepository catalog;
  @override
  Future<CloneVoiceSnapshot> load(String provider) async => CloneVoiceSnapshot(
    pricePoints: ShellClonePorts.prices[normalizeProvider(provider)],
    modelId: provider,
    available: supportsCloneVoice(provider),
    currentStatus: catalog.cloneAssets.contains(provider)
        ? 'READY'
        : 'NOT_CREATED',
    currentHasAsset: catalog.cloneAssets.contains(provider),
  );
  @override
  Future<CallVoiceCatalog> selectConfirmed(String provider) async {
    if (!catalog.cloneAssets.contains(provider)) {
      throw StateError('No mock asset');
    }
    catalog.cloneModes.add(provider);
    return catalog.loadVoices(provider);
  }

  @override
  Future<void> confirmCandidate(String provider) async {
    throw StateError('No pending mock candidate in the management view');
  }

  @override
  Future<void> deleteConfirmed(String provider) async {
    catalog.cloneAssets.remove(provider);
    catalog.cloneModes.remove(provider);
  }
}
