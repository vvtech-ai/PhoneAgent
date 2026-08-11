package com.vvtech.aiassistant

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkSecurityFlavorConfigTest {
    @Test
    fun testEnvironmentFlavorsTrustUserCertificates() {
        listOf("dev", "local").forEach { flavor ->
            val certificateSources = certificateSources(flavorConfig(flavor))

            assertTrue("$flavor must trust system certificates", "system" in certificateSources)
            assertTrue("$flavor must trust user certificates for HTTPS capture", "user" in certificateSources)
        }
    }

    @Test
    fun productionAndDefaultConfigsDoNotTrustUserCertificates() {
        listOf("prod", "main").forEach { flavor ->
            val certificateSources = certificateSources(flavorConfig(flavor))

            assertTrue("$flavor must trust system certificates", "system" in certificateSources)
            assertFalse("$flavor must not trust user certificates", "user" in certificateSources)
        }
    }

    private fun certificateSources(config: File): Set<String> {
        assertTrue("Missing network security config: ${config.path}", config.isFile)
        val document = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(config)
        val certificates = document.getElementsByTagName("certificates")
        return (0 until certificates.length)
            .map { index -> certificates.item(index).attributes.getNamedItem("src").nodeValue }
            .toSet()
    }

    private fun flavorConfig(flavor: String): File {
        val path = "src/$flavor/res/xml/network_security_config.xml"
        return listOf(File(path), File("android/app/$path")).firstOrNull { it.exists() }
            ?: File(path)
    }
}
