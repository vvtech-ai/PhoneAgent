import 'package:flutter/material.dart';
import '../../domain/invite.dart';
import 'invite_activity_card.dart' show InvitePrimaryAction;
import 'invite_rule_paragraphs.dart';
import 'invite_rules_route.dart';

Future<void> showInviteRules(BuildContext context, InviteActivity activity) =>
    showInviteRulesRoute(
      context,
      builder: (context) => _InviteRulesContent(activity: activity),
    );

class _InviteRulesContent extends StatelessWidget {
  const _InviteRulesContent({required this.activity});
  final InviteActivity activity;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            (MediaQuery.sizeOf(context).height -
                    20 -
                    MediaQuery.paddingOf(context).bottom)
                .clamp(0, MediaQuery.sizeOf(context).height),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D7DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              '活动规则',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: InviteRuleParagraphs(text: activity.rules),
              ),
            ),
            InvitePrimaryAction(
              label: '我知道了',
              onPressed: () {
                if (context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
