/// v66 phone-context and long digit-run normalization, without guessing numbers.
abstract final class SpokenPhoneNumber {
  static const _digits = '零〇一二两三四五六七八九十壹贰叁肆伍陆柒捌玖拾幺';
  static const _values = [
    '0',
    '0',
    '1',
    '2',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '1',
  ];
  static final _context = RegExp(
    r'((?:手机号码|手机号|手机|联系电话|电话|号码|联系方式|联系号码|预留电话|预留号码|尾号|后四位|后3位|后4位|后三位|后面四位|末四位)'
    r'\s*(?:是|为|叫|：|:)?\s*)'
    '((?:[$_digits\\d][\\s、,，.。\\-－]*){2,20})',
  );
  static final _longRun = RegExp('([$_digits\\d]\\s*){7,}');
  static final _separators = RegExp(r'[\s、,，.。\-－]+$');

  static String normalize(String text) {
    final contextual = text.replaceAllMapped(_context, (match) {
      final token = match[2]!;
      final suffix = _separators.firstMatch(token)?.group(0) ?? '';
      final core = token.substring(0, token.length - suffix.length);
      return '${match[1]}${_convert(core)}$suffix';
    });
    return contextual.replaceAllMapped(_longRun, (match) {
      final token = match[0]!;
      return token.split('').any(_digits.contains) ? _convert(token) : token;
    });
  }

  static String _convert(String text) => text.split('').map((character) {
    final index = _digits.indexOf(character);
    if (index >= 0) return _values[index];
    return RegExp(r'\d').hasMatch(character) ? character : '';
  }).join();
}
