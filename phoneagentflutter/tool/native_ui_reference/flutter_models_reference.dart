import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';

/// Production model page with synthetic data and no business callbacks.
class FlutterModelsReference extends StatelessWidget {
  const FlutterModelsReference({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: SafeArea(
        child: CallModelsPage(
          state: const CallModelState(
            catalog: CallModelCatalog('QWEN_OMNI_PLUS', [
              CallModel(
                id: 'QWEN_OMNI_PLUS',
                name: 'QwenOmniPlus',
                description: '合成模型一',
                active: true,
                available: true,
                multiplier: 1,
                voiceName: 'Andre',
              ),
              CallModel(
                id: 'DOUBAO',
                name: 'Seeduplex',
                description: '合成模型二',
                active: false,
                available: true,
                multiplier: 2,
                voiceName: '清朗男声',
              ),
            ]),
          ),
          onCreateClone: () {},
          onBack: () {},
          onRetry: () {},
          onSelect: (_) {},
          onVoices: (_) {},
        ),
      ),
    ),
  );
}
