/// Masks phone numbers only when presenting call receipts. Business values stay intact.
String maskCallReceiptPhoneNumbers(String text) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(_phoneLikeRun, (match) {
    final raw = match.group(0)!;
    final result = StringBuffer();
    var partStart = 0;
    var digitsInPart = 0;
    for (var index = 0; index < raw.length; index++) {
      final character = raw[index];
      if (_isSeparator(character) && digitsInPart >= 11) {
        result.write(
          _maskCandidate(
            raw.substring(partStart, index),
            text.substring(0, match.start),
          ),
        );
        result.write(character);
        partStart = index + 1;
        digitsInPart = 0;
      } else if (_spokenDigit.containsKey(character) ||
          character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57) {
        digitsInPart++;
      }
    }
    result.write(
      _maskCandidate(raw.substring(partStart), text.substring(0, match.start)),
    );
    return result.toString();
  });
}

bool _isSeparator(String character) => ' \t·・,，、-－'.contains(character);

String _maskCandidate(String raw, String before) {
  if (raw.isEmpty) return raw;
  final digits = StringBuffer();
  var ambiguous = false;
  for (final rune in raw.runes) {
    final character = String.fromCharCode(rune);
    final digit = _spokenDigit[character];
    if (digit != null) {
      digits.write(digit);
    } else if (rune >= 48 && rune <= 57) {
      digits.write(character);
    } else if ('十拾百佰千仟'.contains(character)) {
      ambiguous = true;
    }
  }
  final number = digits.toString();
  if (!ambiguous &&
      number.length == 11 &&
      number.startsWith(RegExp(r'^1[3-9]'))) {
    return '尾号 ${number.substring(7)}';
  }
  final context = before.substring(before.length > 8 ? before.length - 8 : 0);
  final phoneContext = RegExp(r'电话|号码|手机|联系|回拨').hasMatch(context);
  if (number.length >= 9 &&
      (phoneContext || number.startsWith('1') && ambiguous)) {
    return '电话号码已隐藏';
  }
  return raw;
}

final _phoneLikeRun = RegExp(
  r'[0-9零〇洞一壹幺二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟]'
  r'(?:[ \t·・,，、\-－]*[0-9零〇洞一壹幺二两贰三叁四肆五伍六陆七柒八捌九玖十拾百佰千仟])*',
);

const _spokenDigit = <String, String>{
  '零': '0',
  '〇': '0',
  '洞': '0',
  '一': '1',
  '壹': '1',
  '幺': '1',
  '二': '2',
  '两': '2',
  '贰': '2',
  '三': '3',
  '叁': '3',
  '四': '4',
  '肆': '4',
  '五': '5',
  '伍': '5',
  '六': '6',
  '陆': '6',
  '七': '7',
  '柒': '7',
  '八': '8',
  '捌': '8',
  '九': '9',
  '玖': '9',
};
