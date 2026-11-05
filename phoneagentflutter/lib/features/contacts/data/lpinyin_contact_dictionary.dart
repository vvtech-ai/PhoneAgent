import 'package:lpinyin/lpinyin.dart';
import '../domain/contact_pinyin_search.dart';

/// Pure Dart dictionary adapter shared by Web, Android and iOS.
/// Scoring, candidate selection and input-source rules stay in domain.
class LpinyinContactDictionary implements ContactNameDictionary {
  const LpinyinContactDictionary();

  @override
  String simplify(String value) =>
      ChineseHelper.convertToSimplifiedChinese(value);

  @override
  bool isChinese(String character) => ChineseHelper.isChinese(character);

  @override
  String? firstPinyin(String character) {
    final readings = PinyinHelper.convertToPinyinArray(
      character,
      PinyinFormat.WITHOUT_TONE,
    );
    return readings.isEmpty ? null : readings.first;
  }
}
