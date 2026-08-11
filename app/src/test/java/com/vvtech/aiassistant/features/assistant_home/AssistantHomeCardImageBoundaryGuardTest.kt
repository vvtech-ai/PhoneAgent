package com.vvtech.aiassistant.features.assistant_home

import java.io.File
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeCardImageBoundaryGuardTest {

    @Test
    fun remoteImagesPreferPublishedUrlAndFallbackToBundledCardImage() {
        val section = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeQuickTaskSection.kt"
        ).readText(Charsets.UTF_8)
        val card = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomeQuickTaskCard.kt"
        ).readText(Charsets.UTF_8)
        val mappingFile = sourcePath(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeCardImageResources.kt"
        )

        assertTrue("Home card drawable mapping must live in assistant_home UI.", mappingFile.exists())
        if (!mappingFile.exists()) return
        val mapping = mappingFile.readText(Charsets.UTF_8)

        assertTrue(section.contains("imageUrl = card.imageUrl"))
        assertTrue(section.contains("fallbackImageResId = assistantHomeCardImageRes(card.id)"))
        assertFalse(section.contains("R.drawable.home_card_"))

        assertTrue(card.contains("fallbackImageResId: Int?"))
        assertTrue(card.contains(".load(imageUrl)"))
        assertTrue(card.contains(".placeholder(fallbackImageResId)"))
        assertTrue(card.contains(".error(fallbackImageResId)"))
        assertTrue(card.contains("setImageResource(fallbackImageResId)"))

        listOf(
            "restaurant_booking" to "home_card_restaurant_booking",
            "meeting_invite" to "home_card_meeting_invite",
            "apology" to "home_card_apology",
            "event_invite" to "home_card_event_invite",
            "move_car" to "home_card_move_car",
            "sales_promotion" to "home_card_sales_promotion",
            "simultaneous_interpretation" to "home_card_simultaneous_interpretation"
        ).forEach { (cardId, drawableName) ->
            assertTrue("Missing card ID mapping: $cardId", mapping.contains("\"$cardId\""))
            assertTrue("Missing drawable mapping: $drawableName", mapping.contains("R.drawable.$drawableName"))
        }
    }

    @Test
    fun apkBundlesExactlySevenHomeCardDefaultPngs() {
        val bundledDefaults = sourceFile("src/main/res/drawable-nodpi")
            .listFiles()
            .orEmpty()
            .filter { it.name.startsWith("home_card_") && it.extension == "png" }

        assertTrue(
            "必须打包七张首页卡片默认 PNG: $bundledDefaults",
            bundledDefaults.map { it.name }.toSet() == setOf(
                "home_card_restaurant_booking.png",
                "home_card_meeting_invite.png",
                "home_card_apology.png",
                "home_card_event_invite.png",
                "home_card_move_car.png",
                "home_card_sales_promotion.png",
                "home_card_simultaneous_interpretation.png"
            )
        )
    }

    @Test
    fun bundledDefaultsMatchApprovedSkillImagesByteForByte() {
        val expectedHashes = mapOf(
            "home_card_apology.png" to
                "6D0CFE554760699EB05019C75738B654ACBD134109B79BCB915B06AE0FF538DE",
            "home_card_event_invite.png" to
                "293225A8F346BE3C13A1A489E1FE45B0938172E1BD39E99A061130502E209AFC",
            "home_card_meeting_invite.png" to
                "E977A6C604BA603BC067D3731112349F113C1F8C1833982B25B54EB60C06366E",
            "home_card_move_car.png" to
                "FD5E741A06B5339761D6BCEFA5439FA10B13F81C9064AE90953DA8848A788419",
            "home_card_restaurant_booking.png" to
                "7FFB6536E68933EDBC5E510341F016151A2CB46AD847F9D21FDAD2A7949AFC63",
            "home_card_sales_promotion.png" to
                "D39FAEBE78B896F9A9C740A58149CAA4A415B9C4C7CEF326E19DEDC29E1F7027",
            "home_card_simultaneous_interpretation.png" to
                "4E5E41EFF7BD77B9212C05299C41B1925A946428899036CDFE973E325A29614B"
        )
        val drawableDirectory = sourceFile("src/main/res/drawable-nodpi")

        val actualHashes = expectedHashes.keys.associateWith { fileName ->
            sha256(File(drawableDirectory, fileName))
        }

        assertEquals(expectedHashes, actualHashes)
    }

    private fun sha256(file: File): String {
        check(file.isFile) { "Missing image resource: ${file.absolutePath}" }
        return MessageDigest.getInstance("SHA-256")
            .digest(file.readBytes())
            .joinToString("") { byte -> "%02X".format(byte) }
    }

    private fun sourcePath(path: String): File = File(path)

    private fun sourceFile(path: String): File = sourcePath(path).also {
        check(it.exists()) { "Missing source path: ${it.absolutePath}" }
    }
}
