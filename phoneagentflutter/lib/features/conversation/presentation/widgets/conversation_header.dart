import 'native_conversation_wave.dart';
import 'native_conversation_close.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/auth_tokens.dart';
import '../../domain/conversation_progress.dart';

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.onClose,
    required this.status,
    this.showDetails = true,
    this.progress = ConversationProgress.instruction,
    this.waveMode = NativeConversationWaveMode.standby,
    this.aiSpeechEnabled = true,
    this.onToggleSpeech,
    this.onStatusTap,
  });
  final VoidCallback onClose;
  final String status;
  final bool showDetails;
  final ConversationProgress progress;
  final NativeConversationWaveMode waveMode;
  final bool aiSpeechEnabled;
  final VoidCallback? onToggleSpeech;
  final VoidCallback? onStatusTap;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(18, showDetails ? 22 : 8, 18, 8),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 52),
                    child: Transform.translate(
                      offset: const Offset(0, 2),
                      child: const Text(
                        AuthTokens.brandName,
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 30,
                          height: 39 / 30,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10131A),
                        ),
                      ),
                    ),
                  ),
                  if (showDetails) const SizedBox(height: 6),
                  if (showDetails)
                    Transform.translate(
                      offset: const Offset(0, .75),
                      child: Text(
                        '电话智能体 - 你的语音分身',
                        style: TextStyle(
                          fontSize: 13,
                          height: 20 / 13,
                          letterSpacing:
                              .5 *
                              MediaQuery.textScalerOf(context).scale(13) /
                              13,
                          color: const Color(0xFF717888),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            NativeConversationClose(onClose: onClose),
          ],
        ),
      ),
      if (showDetails)
        ConversationHeaderDetails(
          status: status,
          progress: progress,
          waveMode: waveMode,
          aiSpeechEnabled: aiSpeechEnabled,
          onToggleSpeech: onToggleSpeech,
          onStatusTap: onStatusTap,
        ),
    ],
  );
}

/// Status feedback may scroll when a keyboard leaves little
/// vertical room. The title and close control stay outside that scroll region.
class ConversationHeaderDetails extends StatelessWidget {
  const ConversationHeaderDetails({
    super.key,
    required this.status,
    this.horizontalPadding = 18,
    this.progress = ConversationProgress.instruction,
    this.waveMode = NativeConversationWaveMode.standby,
    this.aiSpeechEnabled = true,
    this.onToggleSpeech,
    this.onStatusTap,
  });
  final String status;
  final double horizontalPadding;
  final ConversationProgress progress;
  final NativeConversationWaveMode waveMode;
  final bool aiSpeechEnabled;
  final VoidCallback? onToggleSpeech;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    child: SizedBox(
      height: 44,
      child: Row(
        children: [
          NativeConversationWave(mode: waveMode),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onStatusTap,
              child: Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D84FC),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Semantics(
              label: aiSpeechEnabled ? '关闭 AI 发声' : '开启 AI 发声',
              button: true,
              enabled: onToggleSpeech != null,
              onTap: onToggleSpeech,
              excludeSemantics: true,
              child: IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                key: const ValueKey('conversation-speech-toggle'),
                onPressed: onToggleSpeech,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: Icon(
                  aiSpeechEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 22,
                  color: aiSpeechEnabled
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFF7A8492),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
