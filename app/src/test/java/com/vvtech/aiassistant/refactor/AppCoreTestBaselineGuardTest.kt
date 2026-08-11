package com.vvtech.aiassistant.refactor

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AppCoreTestBaselineGuardTest {
    @Test
    fun appCoreArchitectureTestBaselineKeepsRequiredSuites() {
        val requiredTests = listOf(
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/domain/task/TaskStatusContractTest.kt",
                snippets = listOf(
                    "class TaskStatusContractTest",
                    "normalizesKnownTaskStatusAliases",
                    "identifiesNetworkAndRecoverableErrorStatuses"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/domain/task/TaskReceiptContractTest.kt",
                snippets = listOf(
                    "class TaskReceiptContractTest",
                    "summarizesBatchReceiptCounts",
                    "TaskReceiptStateReducer.reduce"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/domain/realtime/RealtimeRuntimeEventContractTest.kt",
                snippets = listOf(
                    "class RealtimeRuntimeEventContractTest",
                    "normalizesStableCloseReasons",
                    "reducerAdvancesRuntimeStateAndKeepsCorrelationIds"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/data/repository/AssistantRepositoryAgentEventMappingTest.kt",
                snippets = listOf(
                    "class AssistantRepositoryAgentEventMappingTest",
                    "permissionRequestPayloadCanBeParsedFromNestedClientData",
                    "documentImportPayloadNormalizesListsAndNumericMaxBytes",
                    "deviceContactsLookupClientEventMapsToSignalPayload",
                    "callReadyClientEventMapsToMakeCallRequest",
                    "taskCompletedClientEventMapsCallResultFinal",
                    "unknownAndMalformedAgentEventsAreDropped"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/contacts/ContactPinyinSearchEngineTest.kt",
                snippets = listOf(
                    "class ContactPinyinSearchEngineTest",
                    "search_matchesChineseNameBySeparatedPinyin",
                    "search_prefersExactPinyinOverFuzzyPinyin"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/contacts/DeviceContactResolverPolicyTest.kt",
                snippets = listOf(
                    "class DeviceContactResolverPolicyTest",
                    "extractCallContactCandidateNamesSupportsMultipleContacts",
                    "extractExplicitContactReadsNameAndMainlandMobile",
                    "normalizeDeviceContactPhoneKeepsSupportedDialShapes"
                )
            ),
            RequiredTest(
                path = "src/test/java/com/vvtech/aiassistant/features/assistant/FinalContactMethodPolicyTest.kt",
                snippets = listOf(
                    "class FinalContactMethodPolicyTest",
                    "normalizesMainlandContactPhoneForValidationAndMasking",
                    "outboundDialNumberKeepsFixedLineAndInternationalShapes"
                )
            )
        )

        requiredTests.forEach { required ->
            val file = sourceFile(required.path)
            assertTrue("Missing R33 core test file: ${required.path}", file.exists())
            val source = file.readText(Charsets.UTF_8)
            required.snippets.forEach { snippet ->
                assertTrue(
                    "Missing R33 core test snippet '$snippet' in ${required.path}",
                    source.contains(snippet)
                )
            }
        }
    }

    private data class RequiredTest(
        val path: String,
        val snippets: List<String>
    )

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() || it.path.startsWith("src/") }
        }
    }
}
