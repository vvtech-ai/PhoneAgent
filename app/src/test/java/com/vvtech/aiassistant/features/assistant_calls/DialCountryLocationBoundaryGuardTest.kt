package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DialCountryLocationBoundaryGuardTest {
    @Test
    fun locationIsRequestedOnlyFromExplicitCountryPageAction() {
        val location = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/DialCountryLocationState.kt"
        ).readText(Charsets.UTF_8)
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/DialCountrySelectorPage.kt"
        ).readText(Charsets.UTF_8)
        val startup = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootStartupEffect.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(location.contains("RequestMultiplePermissions"))
        assertTrue(location.contains("Manifest.permission.ACCESS_FINE_LOCATION"))
        assertTrue(location.contains("Manifest.permission.ACCESS_COARSE_LOCATION"))
        assertTrue(location.contains("result.values.any { it }"))
        assertTrue(location.contains("FusedLocationProvider(context).locateOnce()"))
        val provider = sourceFile(
            "src/main/java/com/vvtech/aiassistant/location/FusedLocationProvider.kt"
        ).readText(Charsets.UTF_8)
        assertTrue(provider.contains("LocationManager.NETWORK_PROVIDER"))
        assertTrue(provider.contains("LocationManager.GPS_PROVIDER"))
        assertTrue(provider.contains("8_000L"))
        assertTrue(location.contains("DialCountryLocationPreference"))
        assertTrue(location.contains("preference.save(result.country)"))
        assertTrue(page.contains("onLocationCountrySelected"))
        assertTrue(page.contains("state.requestLocation"))
        assertTrue(page.contains("resolved?.let(onLocationCountrySelected) ?: state.requestLocation()"))
        assertFalse(page.contains("LaunchedEffect(locationState.status"))
        assertFalse(
            "Location permission must not be requested automatically at app startup.",
            startup.contains("add(Manifest.permission.ACCESS_FINE_LOCATION)") ||
                startup.contains("add(Manifest.permission.ACCESS_COARSE_LOCATION)")
        )
    }

    @Test
    fun locatedCountryIsPersistedIndependentlyFromSelectedCountry() {
        val store = FakeLocationStore()
        val preference = DialCountryLocationPreference(store)

        assertTrue(preference.load() == null)
        preference.save(dialCountryByIso("JP"))

        assertTrue(preference.load()?.iso == "JP")
        assertTrue(store.iso == "JP")
    }

    private class FakeLocationStore : DialCountryLocationStore {
        var iso: String? = null

        override fun readIso(): String? = iso

        override fun writeIso(iso: String) {
            this.iso = iso
        }
    }

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
