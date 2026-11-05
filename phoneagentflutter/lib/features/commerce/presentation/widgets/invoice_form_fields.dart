import 'package:flutter/material.dart';

class InvoiceFormField extends StatelessWidget {
  const InvoiceFormField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.keyboard,
    this.hint,
  });
  final Key fieldKey;
  final String label, value;
  final bool enabled;
  final TextInputType? keyboard;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF0F1F3))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(90).clamp(90, 132),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: TextFormField(
            key: fieldKey,
            initialValue: value,
            enabled: enabled,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint ?? '请输入$label',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF858991),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class InvoiceChoiceRow extends StatelessWidget {
  const InvoiceChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.items,
    required this.onChanged,
    this.disabled = const {},
  });
  final String label, selected;
  final Map<String, String> items;
  final Set<String> disabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 47),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF0F1F3))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(90).clamp(90, 132),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 16,
            children: [
              for (final entry in items.entries)
                InkWell(
                  onTap: disabled.contains(entry.key)
                      ? null
                      : () => onChanged(entry.key),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 44,
                        child: Radio<String>(
                          value: entry.key,
                          groupValue: selected,
                          visualDensity: VisualDensity.compact,
                          activeColor: const Color(0xFF1677FF),
                          onChanged: disabled.contains(entry.key)
                              ? null
                              : (value) => onChanged(value!),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 13,
                          color: disabled.contains(entry.key)
                              ? const Color(0xFF91959C)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
