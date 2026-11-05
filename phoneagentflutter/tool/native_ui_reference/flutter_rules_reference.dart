import 'package:flutter/material.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rules_sheet.dart';

/// Opens the production rules route with synthetic text; no invite services.
class FlutterRulesReference extends StatefulWidget {
  const FlutterRulesReference({super.key});
  @override
  State<FlutterRulesReference> createState() => _FlutterRulesReferenceState();
}

class _FlutterRulesReferenceState extends State<FlutterRulesReference> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showInviteRules(
        context,
        const InviteActivity(
          id: 'synthetic',
          name: '合成活动',
          quota: 8,
          inviterPoints: 0,
          inviteePoints: 0,
          rules: '1. 仅限新用户。\n2. 积分以实际到账为准。',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.white);
}
