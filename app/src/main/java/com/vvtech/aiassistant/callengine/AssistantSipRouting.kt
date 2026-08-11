package com.vvtech.aiassistant.callengine

internal object AssistantSipDialNumberFormatter {
    fun toDialNumber(input: String, defaultCountryDialCode: String = ""): String {
        val trimmed = input.trim()
        val digits = trimmed.filter(Char::isDigit)
        val defaultCountryDigits = defaultCountryDialCode.filter(Char::isDigit)
        return when {
            digits.startsWith("0086") -> chinaDomesticDialNumber(digits.drop(4))
            trimmed.startsWith("+86") -> chinaDomesticDialNumber(digits.drop(2))
            digits.startsWith("86") &&
                digits.length in 12..13 &&
                !trimmed.startsWith("+") ->
                chinaDomesticDialNumber(digits.drop(2))
            trimmed.startsWith("+") -> "00$digits"
            digits.startsWith("00") -> digits
            defaultCountryDigits.isNotBlank() && defaultCountryDigits != "86" ->
                if (digits.startsWith(defaultCountryDigits)) "00$digits" else "00$defaultCountryDigits$digits"
            else -> digits
        }
    }

    private fun chinaDomesticDialNumber(national: String): String =
        if (
            national.length in 9..11 &&
            !Regex("1[3-9]\\d{9}").matches(national) &&
            !Regex("(?:400|800|95|96)\\d+").matches(national)
        ) {
            "0$national"
        } else {
            national
        }
}

internal class AssistantSipAccountRouter(
    private val domesticAccounts: List<AssistantSipAccount>,
    private val internationalAccounts: List<AssistantSipAccount>
) {
    fun route(
        targetNumber: String,
        defaultCountryDialCode: String,
        selectedDomesticAccountId: String,
        selectedInternationalAccountId: String
    ): AssistantSipAccount {
        return if (isChinaDomesticNumber(targetNumber, defaultCountryDialCode)) {
            selectAccount(
                accounts = domesticAccounts,
                selectedAccountId = selectedDomesticAccountId,
                defaultAccountId = DefaultDomesticAccountId,
                routeName = "domestic"
            )
        } else {
            selectAccount(
                accounts = internationalAccounts,
                selectedAccountId = selectedInternationalAccountId,
                defaultAccountId = DefaultInternationalAccountId,
                routeName = "international"
            )
        }
    }

    private fun selectAccount(
        accounts: List<AssistantSipAccount>,
        selectedAccountId: String,
        defaultAccountId: String,
        routeName: String
    ): AssistantSipAccount {
        return accounts.firstOrNull { it.id == selectedAccountId && it.configured }
            ?: accounts.firstOrNull { it.id == defaultAccountId && it.configured }
            ?: accounts.firstOrNull { it.configured }
            ?: error("No configured $routeName SIP account")
    }

    private fun isChinaDomesticNumber(targetNumber: String, defaultCountryDialCode: String): Boolean {
        val trimmed = targetNumber.trim()
        val digits = trimmed.filter(Char::isDigit)
        val defaultCountry = defaultCountryDialCode.filter(Char::isDigit)
        val explicitInternationalPrefix = trimmed.startsWith("+") || digits.startsWith("00")
        return when {
            trimmed.startsWith("+86") -> true
            digits.startsWith("0086") -> true
            explicitInternationalPrefix -> false
            defaultCountry.isBlank() || defaultCountry == "86" -> digits.isNotBlank()
            else -> false
        }
    }

    private companion object {
        const val DefaultDomesticAccountId = "auto"
        const val DefaultInternationalAccountId = "auto"
    }
}
