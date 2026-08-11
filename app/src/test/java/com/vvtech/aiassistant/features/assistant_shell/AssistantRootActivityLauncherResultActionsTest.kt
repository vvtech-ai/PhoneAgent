package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class AssistantRootActivityLauncherResultActionsTest {
    @Test
    fun agentPermissionResultConsumesRequestAndReportsGrantedStatus() {
        val request = PermissionRequestPayload(
            permissionKey = "location",
            androidPermission = Manifest.permission.ACCESS_FINE_LOCATION
        )
        val events = mutableListOf<String>()

        handleAssistantAgentPermissionLauncherResult(
            AssistantAgentPermissionLauncherResultCallbacks(
                consumeAgentPermissionRequest = {
                    events += "consume"
                    request
                },
                isAgentPermissionGranted = {
                    events += "check:${it.permissionKey}"
                    true
                },
                onAgentPermissionResult = { resultRequest, status, granted, message ->
                    events += "result:${resultRequest.permissionKey}:$status:$granted:$message"
                }
            )
        )

        assertEquals(
            listOf(
                "consume",
                "check:location",
                "result:location:$AssistantAgentPermissionGrantedStatus:true:$AssistantAgentPermissionGrantedMessage"
            ),
            events
        )
    }

    @Test
    fun agentPermissionResultNoopsWhenRequestMissing() {
        val events = mutableListOf<String>()

        handleAssistantAgentPermissionLauncherResult(
            AssistantAgentPermissionLauncherResultCallbacks(
                consumeAgentPermissionRequest = {
                    events += "consume"
                    null
                },
                isAgentPermissionGranted = {
                    events += "check"
                    false
                },
                onAgentPermissionResult = { _, _, _, _ ->
                    events += "result"
                }
            )
        )

        assertEquals(listOf("consume"), events)
    }

    @Test
    fun agentDocumentResultClearsBeforeCancelOrPickedCallback() {
        val cancelEvents = mutableListOf<String>()
        handleAssistantAgentDocumentLauncherResult(
            uri = null,
            callbacks = AssistantAgentDocumentLauncherResultCallbacks<Any>(
                onClearAgentDocumentRequest = { cancelEvents += "clear" },
                onAgentDocumentPickerCancelled = { cancelEvents += "cancel" },
                onAgentDocumentPicked = { cancelEvents += "picked" }
            )
        )
        assertEquals(listOf("clear", "cancel"), cancelEvents)

        val pickedEvents = mutableListOf<String>()
        val marker = Any()
        handleAssistantAgentDocumentLauncherResult(
            uri = marker,
            callbacks = AssistantAgentDocumentLauncherResultCallbacks(
                onClearAgentDocumentRequest = { pickedEvents += "clear" },
                onAgentDocumentPickerCancelled = { pickedEvents += "cancel" },
                onAgentDocumentPicked = { pickedEvents += "picked:${it === marker}" }
            )
        )
        assertEquals(listOf("clear", "picked:true"), pickedEvents)
    }

    @Test
    fun translationAudioResultUpdatesPermissionBeforeGrantedOrDeniedAction() {
        val grantedEvents = mutableListOf<String>()
        handleAssistantTranslationAudioPermissionResult(
            granted = true,
            callbacks = AssistantTranslationAudioPermissionResultCallbacks(
                onMicrophonePermissionGrantedChange = { grantedEvents += "permission:$it" },
                onAudioPermissionGranted = { grantedEvents += "audio" },
                onShowMessage = { grantedEvents += "message:$it" }
            )
        )
        assertEquals(listOf("permission:true", "audio"), grantedEvents)

        val deniedEvents = mutableListOf<String>()
        handleAssistantTranslationAudioPermissionResult(
            granted = false,
            callbacks = AssistantTranslationAudioPermissionResultCallbacks(
                onMicrophonePermissionGrantedChange = { deniedEvents += "permission:$it" },
                onAudioPermissionGranted = { deniedEvents += "audio" },
                onShowMessage = { deniedEvents += "message:$it" }
            )
        )
        assertEquals(
            listOf("permission:false", "message:$AssistantTranslationAudioPermissionDeniedMessage"),
            deniedEvents
        )
    }

    @Test
    fun startupPermissionsLoadsLocationOnlyWhenLocationGrantedAndAlwaysMarksReady() {
        val deniedEvents = mutableListOf<String>()
        handleAssistantStartupPermissionsResult(
            grantResults = mapOf(Manifest.permission.ACCESS_FINE_LOCATION to false),
            callbacks = AssistantStartupPermissionsResultCallbacks(
                onLoadLocationIfPermitted = { deniedEvents += "location" },
                onTrustedCalleeStartupReadyChange = { deniedEvents += "ready:$it" }
            )
        )
        assertEquals(listOf("ready:true"), deniedEvents)

        val grantedEvents = mutableListOf<String>()
        handleAssistantStartupPermissionsResult(
            grantResults = mapOf(Manifest.permission.ACCESS_COARSE_LOCATION to true),
            callbacks = AssistantStartupPermissionsResultCallbacks(
                onLoadLocationIfPermitted = { grantedEvents += "location" },
                onTrustedCalleeStartupReadyChange = { grantedEvents += "ready:$it" }
            )
        )
        assertEquals(listOf("location", "ready:true"), grantedEvents)
    }

    @Test
    fun resultActionsKeepLauncherResultSemanticsOutOfRootUiDetails() {
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActivityLauncherResultActions.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(action.contains(AssistantAgentPermissionGrantedStatus))
        assertTrue(action.contains(AssistantTranslationAudioPermissionDeniedMessage))
        assertFalse(action.contains("Toast.makeText"))
        assertTrue(action.lines().size <= 300)
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
