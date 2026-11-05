import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/identity_profile.dart';
import 'identity_widgets.dart';

class IdentityEditor extends StatelessWidget {
  const IdentityEditor({
    required this.draft,
    required this.busy,
    required this.verified,
    required this.onName,
    required this.onPhone,
    required this.onGender,
    required this.onSave,
    super.key,
  });
  final IdentityDraft draft;
  final bool busy, verified;
  final ValueChanged<String> onName, onPhone, onGender;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: const Text(
          '身份信息',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      IdentityCard(
        editor: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              '姓名',
              'identity-name',
              draft.name,
              onName,
              readOnly: verified,
              hint: '让AI知道该如何介绍自己',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0x143C3C43)),
            ),
            _field(
              '手机号码',
              'identity-phone',
              draft.contactPhone,
              onPhone,
              phone: true,
              hint: '请输入手机号码',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0x143C3C43)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '性别',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final gender in ['不透露', '男', '女']) ...[
                        if (gender != '不透露') const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            container: true,
                            button: true,
                            label: gender,
                            enabled: !busy,
                            selected: draft.gender == gender,
                            onTap: busy ? null : () => onGender(gender),
                            excludeSemantics: true,
                            child: OutlinedButton(
                              onPressed: busy ? null : () => onGender(gender),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: draft.gender == gender
                                    ? const Color(0xFFE7F0FF)
                                    : const Color(0xFFF7F8FA),
                                foregroundColor: draft.gender == gender
                                    ? ShellTokens.accent
                                    : IdentityStyle.ink,
                                side: BorderSide(
                                  color: draft.gender == gender
                                      ? ShellTokens.accent
                                      : Colors.transparent,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(gender, textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      IdentityAction(
        label: busy ? '保存中' : '保存',
        onTap: busy || draft.name.trim().isEmpty ? null : onSave,
      ),
    ],
  );

  Widget _field(
    String label,
    String id,
    String value,
    ValueChanged<String> onChanged, {
    bool readOnly = false,
    bool phone = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (!phone)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: IdentityStyle.danger),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey(id),
            initialValue: value,
            enabled: !busy && !readOnly,
            readOnly: readOnly,
            onChanged: onChanged,
            keyboardType: phone ? TextInputType.phone : TextInputType.name,
            inputFormatters: [
              if (phone) FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(phone ? 11 : 128),
            ],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: readOnly ? const Color(0xFF8E8E93) : IdentityStyle.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: readOnly
                  ? const Color(0xFFF1F2F4)
                  : const Color(0xFFF7F8FA),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
