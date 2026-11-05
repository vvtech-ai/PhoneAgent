import '../../translation/domain/translation_directory.dart';

/// The live directory owns country availability and shared-code phone rules.
TranslationDirectoryCountry? matchContactDialCountry(
  String digits,
  TranslationDirectory directory,
  String preferredIso,
) {
  final matches = directory.countries.where((country) {
    final code = country.dialCode.replaceAll(RegExp(r'\D'), '');
    return code.isNotEmpty && digits.startsWith(code);
  }).toList();
  if (matches.isEmpty) return null;
  final longest = matches
      .map((country) => country.dialCode.replaceAll(RegExp(r'\D'), '').length)
      .reduce((a, b) => a > b ? a : b);
  final candidates = matches
      .where(
        (country) =>
            country.dialCode.replaceAll(RegExp(r'\D'), '').length == longest,
      )
      .toList();
  if (candidates.length == 1) return candidates.single;
  final matchingRules = candidates
      .where(
        (country) =>
            country.phoneRegex.isNotEmpty && country.acceptsPhone('+$digits'),
      )
      .toList();
  if (matchingRules.length == 1) return matchingRules.single;
  final choices = matchingRules.isEmpty ? candidates : matchingRules;
  return choices
      .where((country) => country.iso == preferredIso.toUpperCase())
      .firstOrNull;
}
