import '../../../../core/design/native_system_chrome.dart';
import '../../../../core/design/android_call_surface.dart';
import '../../../../core/design/ai_content_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/call_transcript.dart';
import '../controller/call_presentation.dart';
import '../controller/call_session_state.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_transcript_viewport.dart';

/// Shared page: production facts and preview facts use the same widgets.
class CallSessionPage extends StatelessWidget {
  const CallSessionPage({
    super.key,
    required this.state,
    required this.monitor,
    required this.modelName,
    required this.seconds,
    required this.onMonitor,
    required this.onHangup,
    required this.onSource,
    this.previewHeader,
    this.targetName = '',
    this.phoneNumber = '',
  });
  final CallSessionState state;
  final CallMonitorView monitor;
  final String modelName;
  final int seconds;
  final VoidCallback onMonitor, onHangup, onSource;
  final Widget? previewHeader;
  final String targetName, phoneNumber;
  @override
  Widget build(BuildContext context) {
    final number = CallPresentation.number(
      state.snapshot?.phoneNumber ?? phoneNumber,
    );
    final name = state.snapshot?.targetName ?? targetName;
    final issue = CallPresentation.issue(state.issue);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NativeSystemChrome.dark,
      child: AndroidCallSurface(
        backgroundColor: const Color(0xFF0B0D12),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101114), Color(0xFF151922), Color(0xFF0B0D12)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 520;
                  final header = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 26, bottom: 36),
                        child: Text(
                          modelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xB8FFFFFF),
                            fontSize: 13,
                            height: 16 / 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        name.isEmpty ? '正在读取通话信息' : name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (number.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            number,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 14),
                        child: Text(
                          CallPresentation.status(state, seconds),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xEBFFFFFF),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                  return Column(
                    children: [
                      if (previewHeader != null) previewHeader!,
                      if (!compact) header,
                      if (issue.isNotEmpty) _notice(issue),
                      Expanded(
                        child: CallTranscriptViewport(
                          revision: state.transcript.lines
                              .map(
                                (line) => '${line.speaker.name}:${line.text}',
                              )
                              .join('\n'),
                          children: [
                            if (compact) header,
                            if (state.transcript.lines.isEmpty &&
                                state.connected)
                              _card('实时对话记录', '等待实时通话转写…'),
                            for (final line in state.transcript.lines)
                              _card(
                                line.speaker == CallSpeaker.assistant
                                    ? 'AI'
                                    : '对方',
                                line.text,
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              AiContentNotice.bottomSpacing -
                              AiContentNotice.iosSafeAreaAdjustment(context),
                        ),
                        child: CallControls(
                          call: state,
                          monitor: monitor,
                          onMonitor: onMonitor,
                          onHangup: onHangup,
                          onSource: onSource,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFFFC978), fontSize: 13),
    ),
  );
  Widget _card(String label, String text) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
