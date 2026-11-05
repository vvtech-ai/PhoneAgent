import '../../../../core/design/native_system_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/translation_call_view.dart';
import '../widgets/translation_call_controls.dart';
import '../widgets/translation_call_identity.dart';
import '../widgets/translation_environment_indicator.dart';
import '../widgets/translation_transcript_thread.dart';

class TranslationCallPage extends StatelessWidget {
  const TranslationCallPage({
    super.key,
    required this.state,
    required this.target,
    required this.controls,
    this.previewHeader,
  });
  final TranslationCallView state;
  final String target;
  final TranslationCallControls controls;
  final Widget? previewHeader;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: NativeSystemChrome.dark,
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1A33), Color(0xFF1A2C52)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(
              children: [
                if (previewHeader != null) previewHeader!,
                Align(
                  alignment: Alignment.centerRight,
                  child: TranslationEnvironmentIndicator(
                    environment: state.environment,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bounds) => Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // DTMF and preview controls can leave a very short thread
                              // on compact phones. Keep controls anchored; scroll the
                              // header with content instead of overflowing the flex.
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14;
                              if (constraints.maxHeight < 140 * scale) {
                                if (state.transcripts.isNotEmpty) {
                                  return TranslationTranscriptThread(
                                    transcripts: state.transcripts,
                                    header: TranslationCallIdentity(
                                      target: target,
                                      state: state,
                                    ),
                                  );
                                }
                                return ListView(
                                  children: [
                                    TranslationCallIdentity(
                                      target: target,
                                      state: state,
                                    ),
                                    const SizedBox(height: 16),
                                    if (state.transcripts.isEmpty)
                                      Text(
                                        state.environment.riskMessage.isEmpty
                                            ? '请清晰地说话，翻译内容会实时显示在这里'
                                            : state.environment.riskMessage,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0x8FFFFFFF),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  TranslationCallIdentity(
                                    target: target,
                                    state: state,
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: state.transcripts.isEmpty
                                        ? Center(
                                            child: Text(
                                              state
                                                      .environment
                                                      .riskMessage
                                                      .isEmpty
                                                  ? '请清晰地说话，翻译内容会实时显示在这里'
                                                  : state
                                                        .environment
                                                        .riskMessage,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0x8FFFFFFF),
                                                fontSize: 14,
                                              ),
                                            ),
                                          )
                                        : TranslationTranscriptThread(
                                            transcripts: state.transcripts,
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        _controlsForHeight(context, bounds.maxHeight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _controlsForHeight(BuildContext context, double height) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (scale <= 1.5 && height >= 480) return controls;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (height - 80 * scale).clamp(0.0, height),
      ),
      child: SingleChildScrollView(
        reverse: true,
        primary: false,
        child: controls,
      ),
    );
  }
}
