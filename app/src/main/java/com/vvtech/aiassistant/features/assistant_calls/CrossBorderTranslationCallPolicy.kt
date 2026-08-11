package com.vvtech.aiassistant.features.assistant_calls

internal fun shouldConfirmCrossBorderTranslationCall(
    translationEnabled: Boolean,
    locationCountryIso: String?,
    calleeCountryIso: String?
): Boolean {
    if (!translationEnabled) return false
    val location = locationCountryIso.orEmpty().trim().uppercase()
    val callee = calleeCountryIso.orEmpty().trim().uppercase()
    return location.isNotBlank() && callee.isNotBlank() && location != callee
}
