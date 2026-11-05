import 'package:flutter/material.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      title: 'PhoneAgent 通话结果播报演练',
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MobilePreview(child: child!),
      home: const CallFlowScenariosPage(),
    ),
  );
}
