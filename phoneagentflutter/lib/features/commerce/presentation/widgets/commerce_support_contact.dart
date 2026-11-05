import 'package:flutter/material.dart';

/// Shared purchase footer; the published catalog remains the email source.
class CommerceSupportContact extends StatelessWidget {
  const CommerceSupportContact({
    super.key,
    required this.email,
    this.onContact,
  });
  final String? email;
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final address = email?.trim() ?? '';
    if (address.isEmpty) return const SizedBox.shrink();
    const style = TextStyle(
      fontSize: 10,
      height: 1.4,
      color: Color(0xFF858991),
    );
    final label = '联系客服：$address';
    return Center(
      child: onContact == null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                label,
                textAlign: TextAlign.center,
                style: style,
              ),
            )
          : TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(top: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onContact,
              child: Text(label, textAlign: TextAlign.center, style: style),
            ),
    );
  }
}
