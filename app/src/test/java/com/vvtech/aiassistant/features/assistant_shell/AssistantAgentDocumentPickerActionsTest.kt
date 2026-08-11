package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentDocumentPickerActionsTest {
    @Test
    fun mimeTypesFilterBlankOctetStreamAndDuplicates() {
        val request = DocumentImportRequestPayload(
            acceptedMimeTypes = listOf(
                " text/plain ",
                "",
                "application/octet-stream",
                "text/plain",
                "text/markdown"
            )
        )

        assertEquals(listOf("text/plain", "text/markdown"), agentDocumentPickerMimeTypes(request))
    }

    @Test
    fun mimeTypesFallbackToTextDefaultsWhenRequestHasNoUsableTypes() {
        val request = DocumentImportRequestPayload(
            acceptedMimeTypes = listOf("", "application/octet-stream")
        )

        assertEquals(listOf("text/plain", "text/markdown", "text/*"), agentDocumentPickerMimeTypes(request))
    }

    @Test
    fun launchDoesNothingWithoutRequest() {
        val recorder = Recorder()

        launchAssistantAgentDocumentPicker(null, recorder.callbacks())

        assertNull(recorder.activeRequest)
        assertTrue(recorder.launches.isEmpty())
        assertTrue(recorder.events.isEmpty())
    }

    @Test
    fun launchStoresActiveRequestAndStartsDocumentPicker() {
        val request = DocumentImportRequestPayload(
            reason = "upload",
            acceptedMimeTypes = listOf("text/plain")
        )
        val recorder = Recorder()

        launchAssistantAgentDocumentPicker(request, recorder.callbacks())

        assertEquals(request, recorder.activeRequest)
        assertEquals(listOf(listOf("text/plain")), recorder.launches)
        assertEquals(listOf("update", "launch:text/plain"), recorder.events)
    }

    @Test
    fun launchFailureClearsShowsMessageAndCancelsInOrder() {
        val request = DocumentImportRequestPayload(reason = "upload")
        val recorder = Recorder(throwOnLaunch = true)

        launchAssistantAgentDocumentPicker(request, recorder.callbacks())

        assertNull(recorder.activeRequest)
        assertEquals(
            listOf(
                "update",
                "launch:text/plain,text/markdown,text/*",
                "clear",
                "message:$AgentDocumentPickerUnavailableMessage",
                "cancel"
            ),
            recorder.events
        )
    }

    @Test
    fun cancelClearsActiveRequestAndCancels() {
        val request = DocumentImportRequestPayload(reason = "upload")
        val recorder = Recorder(activeRequest = request)

        cancelAssistantAgentDocumentPicker(recorder.callbacks())

        assertNull(recorder.activeRequest)
        assertEquals(listOf("clear", "cancel"), recorder.events)
    }

    @Test
    fun rootDelegatesAgentDocumentPickerActionToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantAgentDocumentPickerActions.kt")
                .readText(Charsets.UTF_8)
        val assistantFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText(Charsets.UTF_8)
        val hostShell =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt")
                .readText(Charsets.UTF_8)

        assertFalse(root.contains("val agentDocumentPickerCallbacks = AssistantAgentDocumentPickerCallbacks("))
        assertFalse(root.contains("agentDocumentPicker = agentDocumentPickerCallbacks"))
        assertTrue(hostShell.contains("AssistantAgentDocumentPickerCallbacks("))
        assertTrue(hostShell.contains("agentDocumentPicker = agentDocumentPickerCallbacks()"))
        assertTrue(assistantFactory.contains("launchAssistantAgentDocumentPicker("))
        assertTrue(assistantFactory.contains("cancelAssistantAgentDocumentPicker(actions.agentDocumentPicker)"))
        assertFalse(root.contains("launchAssistantAgentDocumentPicker("))
        assertFalse(root.contains("cancelAssistantAgentDocumentPicker(agentDocumentPickerCallbacks)"))
        assertFalse(root.contains("acceptedMimeTypes"))
        assertFalse(root.contains("application/octet-stream"))
        assertFalse(root.contains("未找到可用的系统文件选择器"))

        assertTrue(action.contains("acceptedMimeTypes"))
        assertTrue(action.contains("application/octet-stream"))
        assertTrue(action.contains(AgentDocumentPickerUnavailableMessage))
    }

    private class Recorder(
        var activeRequest: DocumentImportRequestPayload? = null,
        private val throwOnLaunch: Boolean = false
    ) {
        val launches = mutableListOf<List<String>>()
        val events = mutableListOf<String>()

        fun callbacks(): AssistantAgentDocumentPickerCallbacks {
            return AssistantAgentDocumentPickerCallbacks(
                onUpdateActiveAgentDocumentRequest = {
                    events += "update"
                    activeRequest = it
                },
                onClearAgentDocumentRequest = {
                    events += "clear"
                    activeRequest = null
                },
                onLaunchDocumentPicker = { mimeTypes ->
                    val planned = mimeTypes.toList()
                    events += "launch:${planned.joinToString(",")}"
                    launches += planned
                    if (throwOnLaunch) {
                        error("launcher missing")
                    }
                },
                onAgentDocumentPickerCancelled = {
                    events += "cancel"
                },
                onShowMessage = {
                    events += "message:$it"
                }
            )
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
