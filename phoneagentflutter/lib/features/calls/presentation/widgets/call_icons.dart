import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../controller/call_presentation.dart';

/// Shared outlines match the native Android ic_agent_call resources.
abstract final class CallIcons {
  static const listen =
      '<path d="M6 8.5a6.5 6.5 0 1 1 13 0c0 6-6 6-6 10a3.5 3.5 0 1 1-7 0"/><path d="M15 8.5a2.5 2.5 0 0 0-5 0v1a2 2 0 1 1 0 4"/>';
  static const hangup =
      '<path fill="white" stroke="none" d="M12,9c-1.6,0 -3.15,0.25 -4.6,0.72v3.1c0,0.4 -0.23,0.74 -0.56,0.9 -0.98,0.49 -1.87,1.12 -2.66,1.85 -0.18,0.18 -0.43,0.28 -0.7,0.28s-0.52,-0.11 -0.7,-0.29L0.29,13.08C0.11,12.9 0,12.65 0,12.37s0.11,-0.53 0.29,-0.71C3.34,8.78 7.5,7 12,7s8.66,1.78 11.71,4.67c0.18,0.18 0.29,0.43 0.29,0.71s-0.11,0.53 -0.29,0.71l-2.48,2.48c-0.18,0.18 -0.43,0.29 -0.7,0.29s-0.52,-0.11 -0.7,-0.28c-0.79,-0.73 -1.68,-1.36 -2.66,-1.85 -0.33,-0.16 -0.56,-0.51 -0.56,-0.9v-3.1C15.15,9.25 13.6,9 12,9z"/>';
  static const earpiece =
      '<path d="M7,2h10a2,2 0,0 1,2 2v16a2,2 0,0 1,-2 2H7a2,2 0,0 1,-2 -2V4a2,2 0,0 1,2 -2z"/><path d="M12,18h0.01"/>';
  static const speaker =
      '<path d="M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z"/><path d="M16 9a5 5 0 0 1 0 6"/><path d="M19.364 18.364a9 9 0 0 0 0-12.728"/>';
  static const bluetooth = '<path d="m7 7 10 10-5 5V2l5 5L7 17"/>';
  static String source(CallAudioSource source) => switch (source) {
    CallAudioSource.earpiece => earpiece,
    CallAudioSource.speaker => speaker,
    CallAudioSource.bluetooth => bluetooth,
  };
  static Widget icon(
    String paths, {
    bool off = false,
    Color color = Colors.white,
  }) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$paths${off ? '<path d="M4.5 19.5L19.5 4.5"/>' : ''}</svg>',
    width: 24,
    height: 24,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
