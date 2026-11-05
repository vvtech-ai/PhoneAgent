import 'package:flutter/material.dart';
import '../../data/preview_translation_session.dart';
import '../../domain/translation_call_view.dart';

/// External event injection into the shared session, never direct phase edits.
class TranslationSessionPreviewControls extends StatelessWidget {
  const TranslationSessionPreviewControls({
    super.key,
    required this.fixture,
    required this.state,
  });
  final PreviewTranslationSession fixture;
  final TranslationCallView state;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'MOCK · 无真实电话/音频；记录仅在演练内存',
        style: TextStyle(color: Colors.amber, fontSize: 11),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          if (state.phase == TranslationPhase.preflight)
            TextButton(onPressed: fixture.ready, child: const Text('注入媒体就绪')),
          if (state.phase == TranslationPhase.ringing)
            TextButton(
              onPressed: fixture.connected,
              child: const Text('注入对方接通'),
            ),
          if (state.phase == TranslationPhase.translating)
            TextButton(
              onPressed: fixture.transcript,
              child: const Text('注入双语字幕'),
            ),
          if (state.phase != TranslationPhase.preflight)
            TextButton(onPressed: fixture.ended, child: const Text('注入对方挂断')),
          TextButton(onPressed: fixture.disconnect, child: const Text('注入断线')),
        ],
      ),
    ],
  );
}
