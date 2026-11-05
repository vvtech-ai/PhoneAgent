import 'dial_country.dart';
import 'dial_phone_policy.dart';
import 'contact_dial_country_policy.dart';
import '../../translation/domain/translation_directory.dart';

/// Uses live country rules when available, retaining legacy offline callers.
({String iso, String number, String error}) contactDialInput(
  String raw, {
  String defaultIso = 'CN',
  TranslationDirectory? directory,
}) {
  final text = raw.trim();
  const invalid = (iso: '', number: '', error: '号码格式不正确');
  const unsupported = (iso: '', number: '', error: '暂不支持该号码国家或地区');
  if (!RegExp(r'^[+0-9 ()\.\-]+$').hasMatch(text) ||
      text.substring(1).contains('+')) {
    return invalid;
  }
  var number = DialPhonePolicy.digits(text), iso = defaultIso.toUpperCase();
  if (number.isEmpty) return invalid;
  if (text.startsWith('+') || text.startsWith('00')) {
    if (text.startsWith('00')) number = number.substring(2);
    DialCountry? selected;
    if (directory != null) {
      final configured = matchContactDialCountry(number, directory, iso);
      if (configured != null) {
        selected = DialCountry(
          configured.iso,
          configured.name,
          configured.dialCode,
          '',
          '',
        );
      }
    } else {
      for (final country in dialCountries) {
        if (number.startsWith(country.code.substring(1))) {
          selected = country;
          break;
        }
      }
    }
    if (selected == null) return unsupported;
    iso = selected.iso;
    number = number.substring(selected.code.length - 1);
    if (iso == 'CN' &&
        number.length >= 9 &&
        number.length <= 11 &&
        !RegExp(r'^1[3-9][0-9]{9}$').hasMatch(number)) {
      number = '0$number';
    }
    if (selected.code == '+1') {
      if (!RegExp(r'^[2-9][0-9]{2}[2-9][0-9]{6}$').hasMatch(number)) {
        return invalid;
      }
      if (directory == null &&
          _canadianAreaCodes.contains(int.parse(number.substring(0, 3)))) {
        return unsupported;
      }
    }
  }
  if (directory != null
      ? directory.country(iso) == null
      : dialCountry(iso) == null) {
    return unsupported;
  }
  if (number.isEmpty) return invalid;
  if (number.length > 14) return (iso: '', number: '', error: '号码最多输入14位');
  return (iso: iso, number: number, error: '');
}

const _canadianAreaCodes = {
  204,
  226,
  236,
  249,
  250,
  257,
  263,
  273,
  289,
  306,
  343,
  354,
  365,
  367,
  368,
  382,
  403,
  416,
  418,
  428,
  431,
  437,
  438,
  450,
  468,
  474,
  506,
  514,
  519,
  548,
  579,
  581,
  584,
  587,
  600,
  604,
  613,
  622,
  633,
  639,
  647,
  672,
  683,
  705,
  709,
  742,
  753,
  778,
  780,
  782,
  807,
  819,
  825,
  867,
  873,
  879,
  902,
  905,
  942,
};
