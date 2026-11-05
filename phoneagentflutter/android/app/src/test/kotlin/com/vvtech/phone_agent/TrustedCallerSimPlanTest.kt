package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class TrustedCallerSimPlanTest {
    private val login = "13800000000"
    private val other = "13900000000"

    @Test fun nativeMainlandNormalizationAndInvalidInputs() {
        for (value in listOf(login, "+86 $login", "0086$login", "86$login", "(138) 0000-0000")) {
            assertEquals(login, TrustedCallerSimPlan.normalize(value))
        }
        for (value in listOf(null, "", "synthetic", "12025550100", "12345678901", "138000000000", "１３８００００００００")) {
            assertEquals("", TrustedCallerSimPlan.normalize(value))
        }
    }

    @Test fun missingLoginOrSimDoesNotInventBinding() {
        assertTrue(TrustedCallerSimPlan.writes("", listOf(0), mapOf(0 to other)).isEmpty())
        assertTrue(TrustedCallerSimPlan.writes(login, emptyList(), emptyMap()).isEmpty())
        assertTrue(TrustedCallerSimPlan.writes(login, listOf(-1), emptyMap()).isEmpty())
    }

    @Test fun singleSimPrefersActualAndLabelsFallback() {
        assertEquals(listOf(TrustedCallerSimWrite(1, other, false)),
            TrustedCallerSimPlan.writes(login, listOf(1, 1), mapOf(1 to "+86$other")))
        assertEquals(listOf(TrustedCallerSimWrite(0, login, true)),
            TrustedCallerSimPlan.writes(login, listOf(0), mapOf(0 to "unknown")))
    }

    @Test fun dualSimWritesActualCardsAndOnlySecondaryFallback() {
        assertEquals(listOf(TrustedCallerSimWrite(0, other, false), TrustedCallerSimWrite(1, login, true)),
            TrustedCallerSimPlan.writes(login, listOf(1, 0, 1), mapOf(0 to other)))
        assertEquals(listOf(TrustedCallerSimWrite(1, other, false)),
            TrustedCallerSimPlan.writes(login, listOf(0, 1), mapOf(1 to other)))
        assertEquals(listOf(TrustedCallerSimWrite(1, login, true)),
            TrustedCallerSimPlan.writes(login, listOf(0, 1), emptyMap()))
        assertEquals(listOf(TrustedCallerSimWrite(0, other, false), TrustedCallerSimWrite(1, login, false)),
            TrustedCallerSimPlan.writes(login, listOf(0, 1), mapOf(0 to other, 1 to login)))
    }

    @Test fun multipleSlotsKeepValidNumbersAndUseLastWithoutSecondary() {
        assertEquals(listOf(TrustedCallerSimWrite(0, other, false), TrustedCallerSimWrite(2, login, true)),
            TrustedCallerSimPlan.writes(login, listOf(-1, 2, 0, 2), mapOf(0 to other, 99 to login)))
    }
}
