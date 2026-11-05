bool shouldConfirmCrossBorderTranslationCall({
  required bool translationEnabled,
  required String? callerCountryIso,
  required String? calleeCountryIso,
}) {
  if (!translationEnabled) return false;
  final caller = callerCountryIso?.trim().toUpperCase() ?? '';
  final callee = calleeCountryIso?.trim().toUpperCase() ?? '';
  return caller.isNotEmpty && callee.isNotEmpty && caller != callee;
}
