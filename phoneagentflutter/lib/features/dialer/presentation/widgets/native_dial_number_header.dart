import 'package:flutter/material.dart';
import '../../domain/dial_country.dart';
import '../../domain/dial_phone_policy.dart';
import 'dial_country_rows.dart';

/// Native shared presentation; target validation remains in the controller.
class NativeDialNumberHeader extends StatelessWidget {
  const NativeDialNumberHeader({
    super.key,
    required this.country,
    required this.input,
    required this.onCountry,
  });
  final DialCountry country;
  final String input;
  final VoidCallback? onCountry;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final display = input.isEmpty
        ? '请输入号码'
        : DialPhonePolicy.display(input, country.iso);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (scaler.scale(22) * 1.4 + 16).clamp(80, double.infinity),
      ),
      child: Row(
        children: [
          Semantics(
            container: true,
            button: true,
            enabled: onCountry != null,
            label: '选择国家或地区，${country.name}，${country.code}',
            onTap: onCountry,
            child: ExcludeSemantics(
              child: InkWell(
                key: const Key('dial-country'),
                onTap: onCountry,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DialCountryFlag(country: country),
                      const SizedBox(width: 5),
                      Text(
                        country.code,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 28, color: const Color(0xFFD0D5DD)),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final base = TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: input.isEmpty
                      ? const Color(0xFFB7BAC2)
                      : const Color(0xFF111111),
                );
                final painter = TextPainter(
                  text: TextSpan(text: display, style: base),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final factor = painter.width == 0
                    ? 1.0
                    : (constraints.maxWidth / painter.width).clamp(.75, 1.0);
                painter.dispose();
                return Text(
                  display,
                  key: const Key('dial-number'),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: base.copyWith(fontSize: 22 * factor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
