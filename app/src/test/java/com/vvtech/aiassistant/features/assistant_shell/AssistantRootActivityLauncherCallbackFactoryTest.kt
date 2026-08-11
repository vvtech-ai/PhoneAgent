package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootActivityLauncherCallbackFactoryTest {
    @Test
    fun agentPermissionCallbackDelegatesThroughResultAction() {
        val request = PermissionRequestPayload(
            permissionKey = "location",
            androidPermission = Manifest.permission.ACCESS_FINE_LOCATION
        )
        val events = mutableListOf<String>()
        val callbacks = buildAssistantRootActivityLauncherCallbacks(
            deps = deps(
                events = events,
                consumeAgentPermissionRequest = {
                    events += "consume"
                    request
                },
                isAgentPermissionGranted = {
                    events += "check:${it.permissionKey}"
                    true
                }
            )
        )

        callbacks.onAgentPermissionResult()

        assertEquals(
            listOf(
                "consume",
                "check:location",
                "agent:location:$AssistantAgentPermissionGrantedStatus:true:$AssistantAgentPermissionGrantedMessage"
            ),
            events
        )
    }

    @Test
    fun documentAudioAndStartupCallbacksPreserveResultActionOrder() {
        val events = mutableListOf<String>()
        val callbacks = buildAssistantRootActivityLauncherCallbacks(deps(events))

        callbacks.onAgentDocumentResult(null)
        callbacks.onVoiceCloneAudioPermissionResult(false)
        callbacks.onTranslationCallAudioPermissionResult(false)
        callbacks.onTranslationCallAudioPermissionResult(true)
        callbacks.onStartupPermissionsResult(mapOf(Manifest.permission.ACCESS_COARSE_LOCATION to true))

        assertEquals(
            listOf(
                "clearDocument",
                "cancelDocument",
                "voiceClone:false",
                "microphone:false",
                "message:$AssistantTranslationAudioPermissionDeniedMessage",
                "microphone:true",
                "translationAudio",
                "location",
                "ready:true"
            ),
            events
        )
    }

    @Test
    fun rootDelegatesLauncherCallbacksToFactoryAndFactoryStaysSmall() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActivityLauncherCallbackFactory.kt"
        ).readText(Charsets.UTF_8)
        val permissionRuntime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPermissionRuntimeShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("rememberAssistantRootPermissionRuntime("))
        assertTrue(root.contains("val rootActivityLaunchers = permissionRuntime.rootActivityLaunchers"))
        assertFalse(root.contains("buildAssistantRootActivityLauncherCallbacks("))
        assertFalse(root.contains("AssistantRootActivityLauncherCallbackFactoryDeps("))
        assertFalse(root.contains("rememberAssistantRootActivityLaunchers(rootActivityLauncherCallbacks)"))
        assertFalse(Regex("""(?m)^\s*AssistantRootActivityLauncherCallbacks\(""").containsMatchIn(root))
        assertFalse(root.contains("handleAssistantAgentPermissionLauncherResult("))
        assertFalse(root.contains("handleAssistantAgentDocumentLauncherResult("))
        assertFalse(root.contains("handleAssistantVoiceCloneAudioPermissionResult("))
        assertFalse(root.contains("handleAssistantTranslationAudioPermissionResult("))
        assertFalse(root.contains("handleAssistantStartupPermissionsResult("))

        assertTrue(factory.contains("AssistantRootActivityLauncherCallbacks("))
        assertTrue(factory.contains("handleAssistantAgentPermissionLauncherResult("))
        assertTrue(factory.contains("handleAssistantAgentDocumentLauncherResult("))
        assertTrue(factory.contains("handleAssistantVoiceCloneAudioPermissionResult("))
        assertTrue(factory.contains("handleAssistantTranslationAudioPermissionResult("))
        assertTrue(factory.contains("handleAssistantStartupPermissionsResult("))
        assertTrue(factory.lines().size <= 300)

        assertTrue(permissionRuntime.contains("buildAssistantRootActivityLauncherCallbacks("))
        assertTrue(permissionRuntime.contains("AssistantRootActivityLauncherCallbackFactoryDeps("))
        assertTrue(permissionRuntime.contains("rememberAssistantRootActivityLaunchers(rootActivityLauncherCallbacks)"))
        assertTrue(permissionRuntime.lines().size <= 300)
    }

    private fun deps(
        events: MutableList<String>,
        consumeAgentPermissionRequest: () -> PermissionRequestPayload? = { null },
        isAgentPermissionGranted: (PermissionRequestPayload) -> Boolean = { false }
    ): AssistantRootActivityLauncherCallbackFactoryDeps =
        AssistantRootActivityLauncherCallbackFactoryDeps(
            consumeAgentPermissionRequest = consumeAgentPermissionRequest,
            isAgentPermissionGranted = isAgentPermissionGranted,
            onAgentPermissionResult = { request, status, granted, message ->
                events += "agent:${request.permissionKey}:$status:$granted:$message"
            },
            onClearAgentDocumentRequest = { events += "clearDocument" },
            onAgentDocumentPickerCancelled = { events += "cancelDocument" },
            onAgentDocumentPicked = { events += "pickedDocument" },
            onVoiceCloneAudioPermissionResult = { events += "voiceClone:$it" },
            onMicrophonePermissionGrantedChange = { events += "microphone:$it" },
            onTranslationAudioPermissionGranted = { events += "translationAudio" },
            onShowMessage = { events += "message:$it" },
            onLoadLocationIfPermitted = { events += "location" },
            onTrustedCalleeStartupReadyChange = { events += "ready:$it" }
        )

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
