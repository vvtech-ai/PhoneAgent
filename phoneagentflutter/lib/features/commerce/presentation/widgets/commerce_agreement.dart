import 'package:flutter/material.dart';
import 'membership_agreement_line.dart';

class CommerceAgreement extends StatelessWidget {
  const CommerceAgreement({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onLegal,
    this.membership = false,
  });
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLegal;
  final bool membership;

  @override
  Widget build(BuildContext context) => membership
      ? MembershipAgreementLine(
          accepted: accepted,
          onChanged: onChanged,
          onLegal: onLegal,
        )
      : Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 44,
                child: Checkbox(
                  value: accepted,
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Color(0xFF858991), width: 1),
                  activeColor: const Color(0xFF1677FF),
                  onChanged: (value) => onChanged(value == true),
                ),
              ),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '我已阅读并同意',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF6F747D),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onLegal,
                      child: Text(
                        '付费服务协议',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF3478F5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
}
