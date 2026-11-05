import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../identity/domain/identity_profile.dart';
export 'initialization_model_cards.dart';

class InitializationIdentityFields extends StatelessWidget {
  const InitializationIdentityFields({
    super.key,
    required this.draft,
    required this.busy,
    required this.onName,
    required this.onGender,
    required this.onPhone,
  });
  final IdentityDraft draft;
  final bool busy;
  final ValueChanged<String> onName, onGender, onPhone;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field('姓名', 'init-name', draft.name, onName, hint: '让AI知道该如何介绍自己'),
      const SizedBox(height: 12),
      const Text(
        '性别',
        style: TextStyle(
          fontSize: 12,
          height: 14 / 12,
          letterSpacing: 0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4B5563),
        ),
      ),
      const SizedBox(height: 7),
      Row(
        children: [
          for (final gender in ['不透露', '男', '女']) ...[
            if (gender != '不透露') const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                label: gender,
                selected: gender == draft.gender,
                enabled: !busy,
                onTap: busy ? null : () => onGender(gender),
                excludeSemantics: true,
                child: OutlinedButton(
                  onPressed: busy ? null : () => onGender(gender),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: BorderSide(
                      color: gender == draft.gender
                          ? const Color(0x520A84FF)
                          : const Color(0x1F3C3C43),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    foregroundColor: gender == draft.gender
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF4B5563),
                    backgroundColor: gender == draft.gender
                        ? const Color(0x1A0A84FF)
                        : const Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    gender,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 16 / 13,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _field(
        '手机号码',
        'init-phone',
        draft.contactPhone,
        onPhone,
        hint: '请输入手机号码（可不填）',
        phone: true,
      ),
    ],
  );
  Widget _field(
    String label,
    String key,
    String value,
    ValueChanged<String> change, {
    required String hint,
    bool phone = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          height: 14 / 12,
          letterSpacing: 0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4B5563),
        ),
      ),
      const SizedBox(height: 7),
      TextFormField(
        key: ValueKey(key),
        initialValue: value,
        onChanged: change,
        enabled: !busy,
        keyboardType: phone ? TextInputType.phone : TextInputType.name,
        inputFormatters: phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ]
            : [LengthLimitingTextInputFormatter(128)],
        style: TextStyle(
          fontSize: 15,
          height: 18 / 15,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
          color: busy ? const Color(0xFF6E6E73) : const Color(0xFF111111),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 13,
            height: 16 / 13,
            letterSpacing: 0,
            fontWeight: FontWeight.w500,
            color: Color(0x5C3C3C43),
          ),
          filled: true,
          fillColor: busy ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          border: _border(const Color(0x213C3C43)),
          enabledBorder: _border(const Color(0x213C3C43)),
          disabledBorder: _border(const Color(0x213C3C43)),
          focusedBorder: _border(const Color(0xFF0A84FF)),
        ),
      ),
    ],
  );
  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}
