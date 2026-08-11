package com.vvtech.aiassistant.features.assistant_shell

import android.Manifest
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentPermissionGrantPolicyTest {
    @Test
    fun locationPermissionPlanAcceptsFineOrCoarseLocation() {
        val plan = assistantAgentPermissionCheckPlan(
            PermissionRequestPayload(permissionKey = "location")
        )

        assertFalse(plan.alwaysGranted)
        assertEquals(
            listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            plan.androidPermissions
        )
    }

    @Test
    fun documentPickerPermissionPlanIsAlwaysGranted() {
        val plan = assistantAgentPermissionCheckPlan(
            PermissionRequestPayload(permissionKey = "document_picker")
        )

        assertTrue(plan.alwaysGranted)
        assertEquals(emptyList<String>(), plan.androidPermissions)
    }

    @Test
    fun androidPermissionPlanRejectsBlankPermission() {
        val blank = assistantAgentPermissionCheckPlan(
            PermissionRequestPayload(permissionKey = "contacts", androidPermission = "")
        )
        val concrete = assistantAgentPermissionCheckPlan(
            PermissionRequestPayload(
                permissionKey = "contacts",
                androidPermission = Manifest.permission.READ_CONTACTS
            )
        )

        assertFalse(blank.alwaysGranted)
        assertEquals(emptyList<String>(), blank.androidPermissions)
        assertEquals(listOf(Manifest.permission.READ_CONTACTS), concrete.androidPermissions)
    }

    @Test
    fun rootDelegatesAgentPermissionGrantPolicyToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val secondaryShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootSecondaryShellEffects.kt"
        ).readText(Charsets.UTF_8)
        val policy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantAgentPermissionGrantPolicy.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(root.contains("isAssistantAgentPermissionGranted(context, request)"))
        assertTrue(secondaryShell.contains("isAssistantAgentPermissionGranted(context, request)"))
        assertFalse(root.contains("when (request.permissionKey)"))
        assertFalse(root.contains("\"location\" ->"))
        assertFalse(root.contains("\"document_picker\" -> true"))

        assertTrue(policy.contains("assistantAgentPermissionCheckPlan"))
        assertTrue(policy.lines().size <= 300)
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
