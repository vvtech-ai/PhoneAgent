import 'package:flutter/material.dart';

class NativeDialPad extends StatelessWidget {
  const NativeDialPad({super.key, this.onDigit});
  final ValueChanged<String>? onDigit;
  static const digits = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];
  static const letters = [
    '',
    'ABC',
    'DEF',
    'GHI',
    'JKL',
    'MNO',
    'PQRS',
    'TUV',
    'WXYZ',
    '',
    '+',
    '',
  ];
  static double keyHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return (scale.scale(24) * 1.2 + scale.scale(9) * 1.2 + 12).clamp(
      64,
      double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = keyHeight(context);
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final scaler = MediaQuery.textScalerOf(context);
    final digitHeight = scaler.scale(24) * 1.2;
    final offset = 7 * scaler.scale(24) / 24;
    Widget label(int index) {
      final main = Text(
        digits[index],
        key: ValueKey('dial-digit-${digits[index]}'),
        style: const TextStyle(
          fontSize: 24,
          height: 1.2,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
      );
      final sub = Text(
        letters[index],
        key: ValueKey('dial-letters-${digits[index]}'),
        style: const TextStyle(
          fontSize: 9,
          height: 1.2,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: Color(0xFF70737B),
        ),
      );
      if (!ios) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [main, if (letters[index].isNotEmpty) sub],
        );
      }
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, letters[index].isEmpty ? 0 : -offset),
            child: SizedBox(height: digitHeight, child: main),
          ),
          if (letters[index].isNotEmpty)
            Positioned(
              top:
                  height / 2 -
                  offset +
                  digitHeight / 2 +
                  scaler.scale(9) * 2 / 9,
              left: 0,
              right: 0,
              child: Center(child: sub),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Expanded(
                  child: Container(
                    height: height,
                    foregroundDecoration: BoxDecoration(
                      border: Border(
                        top: const BorderSide(color: Color(0xFFE5E8EE)),
                        right: col < 2
                            ? const BorderSide(color: Color(0xFFE5E8EE))
                            : BorderSide.none,
                      ),
                    ),
                    child: TextButton(
                      key: Key('dial-key-${digits[row * 3 + col]}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onDigit == null
                          ? null
                          : () => onDigit!(digits[row * 3 + col]),
                      child: SizedBox(
                        width: double.infinity,
                        height: height,
                        child: label(row * 3 + col),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
