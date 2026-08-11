package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantContactDirectoryRuntimeControllerGuardTest {
    @Test
    fun runtimeDelegatesDirectorySideEffectsToDirectoryController() {
        val runtime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val directory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactDirectoryRuntimeController.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(runtime.lines().size < 500)
        assertTrue(directory.lines().size <= 220)
        assertTrue(runtime.contains("private val directoryController: AssistantContactDirectoryRuntimeController"))

        listOf(
            "fun refreshDeviceContacts(onComplete: (() -> Unit)? = null) =",
            "directoryController.refreshDeviceContacts(onComplete)",
            "fun refreshContactDirectory() =",
            "directoryController.refreshContactDirectory()",
            "fun saveContactDirectoryEntry(request: ContactDirectoryUpsertRequest) =",
            "directoryController.saveContactDirectoryEntry(request)",
            "fun deleteContactDirectoryEntry(phone: String) =",
            "directoryController.deleteContactDirectoryEntry(phone)"
        ).forEach { token ->
            assertTrue("runtime should keep thin delegate: $token", runtime.contains(token))
        }

        listOf(
            "DeviceContactResolver(",
            "ContextCompat.checkSelfPermission",
            "DevMockHooks.bypassContactsPermission",
            "android.Manifest.permission.READ_CONTACTS",
            "repository.listContacts",
            "repository.upsertContact",
            "repository.deleteContact"
        ).forEach { token ->
            assertFalse("directory side effect should stay out of runtime: $token", runtime.contains(token))
            assertTrue("directory controller should own side effect: $token", directory.contains(token))
        }
    }

    @Test
    fun contactPageUiAndPhoneKeyHelperStayInContactsBoundary() {
        val legacyPage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalContactsPage.kt"
        ).readText(Charsets.UTF_8)
        val contactsPage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactsPage.kt"
        ).readText(Charsets.UTF_8)
        val rows = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactRows.kt"
        ).readText(Charsets.UTF_8)
        val runtime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val directory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactDirectoryRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val detailPage = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactDetailPage.kt"
        ).readText(Charsets.UTF_8)
        val remarkEditor = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactRemarkEditor.kt"
        ).readText(Charsets.UTF_8)
        val remarkRequest = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactRemarkRequest.kt"
        ).readText(Charsets.UTF_8)
        val hostArgs = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactPageHostArgs.kt"
        ).readText(Charsets.UTF_8)
        val host = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactPageHost.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(legacyPage.lines().size <= 80)
        assertTrue(contactsPage.lines().size < 300)
        assertTrue(rows.lines().size < 300)
        assertTrue(detailPage.lines().size < 300)
        assertTrue(remarkEditor.lines().size < 300)
        assertTrue(legacyPage.contains("AssistantContactsPage("))
        assertTrue(legacyPage.contains("AssistantContactDetailPage("))
        assertTrue(legacyPage.contains("normalizeAssistantContactPhoneKey(raw)"))
        assertFalse("Contact list must not render directory remark summaries.", contactsPage.contains("directoryAnnotations"))
        assertFalse("Contact rows must not accept directory annotations.", rows.contains("AssistantContactDirectoryAnnotation"))
        assertFalse("Contact rows must not build remark summary copy.", rows.contains("assistantContactAnnotationText"))
        assertFalse("Runtime must not derive list-only directory annotations.", runtime.contains("contactDirectoryAnnotations"))

        listOf(
            "LazyColumn(",
            "AssistantContactPlainRow",
            "AssistantContactAvatar",
            "AssistantContactProfileAction",
            "assistantContactAnnotationText",
            "Brush.verticalGradient",
            "drawLine("
        ).forEach { token ->
            assertFalse("legacy contacts page should only bridge: $token", legacyPage.contains(token))
        }

        listOf(
            "AssistantContainer",
            "AppContainer",
            "Repository",
            "ContextCompat.checkSelfPermission",
            "DeviceContactResolver",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "AudioPlayer",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream"
        ).forEach { token ->
            assertFalse("contacts UI should not depend on runtime/data: $token", contactsPage.contains(token))
            assertFalse("contacts rows should not depend on runtime/data: $token", rows.contains(token))
        }

        assertTrue(runtime.contains("normalizeAssistantContactPhoneKey"))
        assertTrue(directory.contains("normalizeAssistantContactPhoneKey"))
        assertFalse(directory.contains("import com.vvtech.aiassistant.features.assistant.normalizeFinalContactPhoneKey"))
        assertFalse(runtime.contains("normalizeFinalContactPhoneKey(it.phone)"))
        assertFalse(runtime.contains("normalizeFinalContactPhoneKey(directoryDetailPhone)"))
        assertTrue(detailPage.contains("AssistantContactRemarkEditor("))
        assertTrue(detailPage.contains("label = \"拨打电话\""))
        assertTrue("Contact detail must expose the prototype task entry.", detailPage.contains("发起任务"))
        assertTrue("Contact detail callbacks must retain the task action.", detailPage.contains("onTask"))
        val detailActions = detailPage.substringAfter("private fun AssistantContactDetailActions")
        assertTrue(
            "Contact detail must render the call and task profile actions.",
            detailActions.split("AssistantContactProfileAction(").size - 1 == 2
        )
        assertTrue(
            "The prototype actions must share the available width.",
            detailActions.split("Modifier.weight(1f)").size - 1 == 2
        )
        assertTrue(remarkEditor.contains("text = \"编辑备注\""))
        assertTrue(remarkEditor.contains("OutlinedTextField("))
        listOf("displayName", "primaryRelation", "speakingStyle").forEach { field ->
            assertFalse("Remark editor must not expose another directory field: $field", remarkEditor.contains(field))
            assertTrue("Remark request must preserve the existing directory field: $field", remarkRequest.contains(field))
        }
        val saveBlock = directory
            .substringAfter("fun saveContactDirectoryEntry")
            .substringBefore("fun deleteContactDirectoryEntry")
        assertFalse("Saving a remark should stay on contact detail.", saveBlock.contains("callbacks.onPageChange"))
        assertTrue(
            "Contact list selection should open the read-only contact detail page.",
            hostArgs.contains("navigation.onPageChange(FinalPage.ContactDetail)")
        )
        assertFalse(
            "Contact list selection must not jump directly into the full directory editor.",
            hostArgs.substringBefore("contactDetail = ContactDetailPageHostArgs(")
                .contains("navigation.onPageChange(FinalPage.ContactDirectoryDetail)")
        )
        val contactDetailArgs = hostArgs
            .substringAfter("contactDetail = ContactDetailPageHostArgs(")
            .substringBefore("directoryDetail = ContactDirectoryDetailPageHostArgs(")
        assertTrue(
            "Contact detail host args must expose Skill selection.",
            contactDetailArgs.contains("onSkillSelected")
        )
        val contactDetailHost = host
            .substringAfter("FinalPage.ContactDetail ->")
            .substringBefore("FinalPage.ContactDirectoryDetail ->")
        assertTrue(
            "Contact detail PageHost must forward Skill selection.",
            contactDetailHost.contains("onSkillSelected")
        )
    }

    @Test
    fun contactTaskEntryDoesNotRestoreLegacyIdentityBlockingCallbacks() {
        val sources = listOf(
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactArgsBuilder.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantContactRuntimeController.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantPageHostArgs.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsContract.kt"),
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt")
        ).associateWith { it.readText(Charsets.UTF_8) }

        listOf("onStartTaskFlow", "onBlockAssistantEntryIfIdentityIncomplete").forEach { callback ->
            sources.forEach { (source, text) ->
                assertFalse(
                    "Contact task entry must not restore legacy callback across ${source.name}: $callback",
                    text.contains(callback)
                )
            }
        }
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
