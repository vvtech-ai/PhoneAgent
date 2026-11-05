import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/conversation/presentation/pages/voice_input_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'PhoneAgent 统一对话输入演练',
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      home: const VoiceInputPreviewPage(),
    ),
  );
}
