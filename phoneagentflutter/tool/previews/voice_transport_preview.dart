import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/settings/presentation/pages/voice_transport_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'PhoneAgent 语音网关演练',
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      home: const VoiceTransportPreviewPage(),
    ),
  );
}
