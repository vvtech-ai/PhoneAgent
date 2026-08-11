package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootImportSurfaceGuardTest {
    @Test
    fun rootKeepsOnlyShellCompositionImports() {
        val rootFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
        val root = rootFile.readText(Charsets.UTF_8)
        val imports = root.lineSequence()
            .filter { it.startsWith("import ") }
            .toList()

        assertTrue("AssistantRootScreen must stay under 500 lines.", rootFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(imports.contains("import androidx.compose.runtime.Composable"))
        assertTrue(imports.contains("import androidx.compose.runtime.NonRestartableComposable"))
        assertTrue(imports.contains("import androidx.lifecycle.compose.collectAsStateWithLifecycle"))
        assertTrue(imports.contains("import com.vvtech.aiassistant.features.assistant_shell.*"))
        assertFalse(imports.contains("import android.widget.Toast"))
        assertFalse(root.contains("Toast.makeText"))
        assertFalse(root.contains("未授予电话权限，已中止本次通话"))
        assertFalse(root.contains("AppFileLogger"))
        assertFalse(root.contains("DevMockHooks"))
        assertFalse(root.contains("mockResultPageFallbackCallId"))
        assertTrue(root.contains("rememberAssistantRootUserMessageActions(context)"))
        assertTrue(root.contains("onPermissionDenied = rootUserMessages::showSystemPhonePermissionDenied"))
        assertTrue(root.contains("onShowMessage = rootUserMessages::showMessage"))
        assertTrue(root.contains("log = ::logAssistantRootWarning"))
        assertTrue(root.contains("resultCallIdFallback = assistantRootResultCallIdFallback()"))

        bannedImportPrefixes.forEach { prefix ->
            assertFalse(
                "$prefix must not return to AssistantRootScreen; put UI implementation in shell/page files.",
                imports.any { it.startsWith(prefix) }
            )
        }
        assertFalse(root.contains("@OptIn(ExperimentalAnimationApi::class)"))
    }

    @Test
    fun rootUserMessageSideEffectsStayInShellAction() {
        val shell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootUserMessageActions.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(shell.contains("Toast.makeText(context, message, Toast.LENGTH_SHORT).show()"))
        assertTrue(shell.contains("未授予电话权限，已中止本次通话"))
        assertTrue(shell.contains("fun showSystemPhonePermissionDenied()"))
        assertTrue(shell.lines().size <= 80)
    }

    @Test
    fun rootDiagnosticsAndDevHooksStayInShellHelpers() {
        val shell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootDiagnosticsHooks.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(shell.contains("AppFileLogger.w(AssistantRootLogTag, message)"))
        assertTrue(shell.contains("DevMockHooks.mockResultPageFallbackCallId()"))
        assertTrue(shell.contains("private const val AssistantRootLogTag = \"AssistantRootScreen\""))
        assertTrue(shell.lines().size <= 40)
    }

    private companion object {
        val bannedImportPrefixes = listOf(
            "import androidx.compose.animation.",
            "import androidx.compose.foundation.",
            "import androidx.compose.material.",
            "import androidx.compose.ui.Alignment",
            "import androidx.compose.ui.Modifier",
            "import androidx.compose.ui.draw.",
            "import androidx.compose.ui.geometry.",
            "import androidx.compose.ui.graphics.",
            "import androidx.compose.ui.layout.",
            "import androidx.compose.ui.res.",
            "import androidx.compose.ui.text.",
            "import androidx.compose.ui.unit."
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
