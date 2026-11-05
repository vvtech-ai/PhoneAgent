import 'package:flutter/material.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import 'flutter_models_reference.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/voice_sheet_frame.dart';

/// The production current modal composition; no media host or service ports.
class FlutterVoicesReference extends StatefulWidget {
  const FlutterVoicesReference({super.key});
  @override
  State<FlutterVoicesReference> createState() => _FlutterVoicesReferenceState();
}

class _FlutterVoicesReferenceState extends State<FlutterVoicesReference> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        barrierColor: const Color(0x73000000),
        constraints: const BoxConstraints(maxWidth: 420),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (sheetContext) => VoiceSheetFrame(
          child: CallVoicesPage(
            state: const CallModelState(
              voiceProvider: 'QWEN_OMNI_PLUS',
              voices: CallVoiceCatalog('Andre', 'AI', [
                CallVoice('Andre', 'Andre', '合成样音', true),
                CallVoice('Ethan', 'Ethan', '合成样音', false),
                CallVoice('Katerina', 'Katerina', '合成样音', false),
              ]),
              clone: CloneVoiceSnapshot(
                modelId: 'QWEN_OMNI_PLUS',
                available: true,
                currentStatus: 'NONE',
                currentHasAsset: false,
              ),
            ),
            onBack: () => Navigator.pop(sheetContext),
            onRetry: () {},
            onSelect: (_) {},
            onSelectClone: () {},
            onCreateClone: () {},
            onPreview: (_) {},
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const FlutterModelsReference();
}
