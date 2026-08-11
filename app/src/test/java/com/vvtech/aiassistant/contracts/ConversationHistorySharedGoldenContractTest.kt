package com.vvtech.aiassistant.contracts

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.MessageDigest

class ConversationHistorySharedGoldenContractTest {

    @Test
    fun backendGoldenFilesArePinnedAndParseable() {
        PINNED_SHA256.forEach { (name, expectedHash) ->
            val bytes = resourceBytes(name)
            assertEquals("Unexpected contract drift in $name", expectedHash, bytes.sha256())
            assertNotNull("Invalid JSON in $name", JsonParser().parse(bytes.toString(Charsets.UTF_8)))
        }
    }

    @Test
    fun eventTypesAndPayloadSchemasStayInLockstep() {
        val eventTypes = jsonObject("event-types.json")
        assertEquals(1, eventTypes.int("schemaVersion"))
        assertEquals(
            "preserve_raw_identity_advance_cursor_skip_projection",
            eventTypes.string("unknownEventStrategy"),
        )
        val wireNames = eventTypes.array("wireNames").strings()
        assertEquals(EXPECTED_EVENT_TYPES, wireNames.toSet())
        assertEquals(EXPECTED_EVENT_TYPES.size, wireNames.size)

        val payloadSchemas = jsonObject("payload-schemas.json")
        val commonIdentityFields = payloadSchemas.array("commonIdentityFields").strings().toSet()
        assertEquals(EXPECTED_COMMON_IDENTITY_FIELDS, commonIdentityFields)
        val schemas = payloadSchemas.array("events").objects()
        assertEquals(EXPECTED_EVENT_TYPES, schemas.map { it.string("eventType") }.toSet())
        val outcomeSchema = schemas.single { it.string("eventType") == "CALL_OUTCOME_REPORTED" }
        assertTrue(
            "receiptFields must remain optional for legacy events",
            "receiptFields" in outcomeSchema.array("optionalPayloadFields").strings(),
        )
        schemas.forEach { schema ->
            assertEquals(1, schema.int("schemaVersion"))
            assertTrue(schema.array("requiredPayloadFields").size() > 0)
            assertTrue(schema.array("requiredCorrelationFields").size() > 0)
            assertNotNull(schema.get("optionalPayloadFields"))
        }
    }

    @Test
    fun timelinePageAndCommittedSseShareTheSameDurableEvent() {
        val page = jsonObject("timeline-page.json")
        assertEquals("session-23065", page.string("sessionId"))
        assertEquals(1, page.int("schemaVersion"))
        assertEquals(4L, page.long("ledgerHeadSequence"))
        assertEquals(3L, page.long("requestedAfterSequence"))
        assertEquals(4L, page.long("firstSequence"))
        assertEquals(4L, page.long("lastSequence"))
        assertEquals(4L, page.long("nextAfterSequence"))
        assertFalse(page.get("hasMore").asBoolean)

        val projection = page.obj("projection")
        assertEquals("INCOMPLETE", projection.string("conversationStatus"))
        assertTrue(projection.get("conversationContinuable").asBoolean)
        assertFalse(projection.get("pendingToolRestorable").asBoolean)
        assertEquals("COMPLETE", projection.string("migrationStatus"))
        assertEquals(4L, projection.long("projectedThroughSequence"))

        val event = page.array("events")[0].asJsonObject
        val committed = jsonObject("timeline-committed-sse.json")
        assertEquals("timeline_committed", committed.string("event"))
        val sseData = committed.obj("data")
        assertEquals(event, sseData)
        EXPECTED_COMMON_IDENTITY_FIELDS.forEach { field ->
            assertTrue("timeline event missing $field", event.has(field))
            assertTrue("committed SSE missing $field", sseData.has(field))
        }
        assertEquals("CALL_COMPLETED", event.string("eventType"))
        assertEquals("embedded_sip", event.obj("payload").string("provider"))
        assertEquals("connected", event.obj("payload").string("resultCode"))
    }

    @Test
    fun errorsOutboxAndMigrationStatusRemainExplicit() {
        val errors = jsonArray("timeline-errors.json").objects().associateBy { it.string("errorCode") }
        assertEquals(EXPECTED_TIMELINE_ERRORS, errors.keys)
        val migrationError = errors.getValue("TIMELINE_MIGRATION_INCOMPLETE")
        assertEquals(409, migrationError.int("httpStatus"))
        assertTrue(migrationError.get("retryable").asBoolean)
        assertEquals("WAIT_FOR_MIGRATION", migrationError.string("recoveryAction"))
        assertEquals("NONE", migrationError.string("sideEffect"))

        val outbox = jsonObject("outbox-transitions.json")
        assertEquals(setOf("CLAIMED", "CANCELLED", "REJECTED"), outbox.array("PENDING").strings().toSet())
        assertEquals(
            setOf("UNKNOWN", "COMPLETED", "FAILED", "CANCELLED", "REJECTED"),
            outbox.array("DISPATCHING").strings().toSet(),
        )
        assertEquals(setOf("COMPLETED", "FAILED", "CANCELLED", "REJECTED"), outbox.array("UNKNOWN").strings().toSet())
        listOf("COMPLETED", "FAILED", "CANCELLED", "REJECTED").forEach { terminal ->
            assertEquals(0, outbox.array(terminal).size())
        }

        val idempotencyKinds = jsonArray("idempotency-vectors.json").objects()
            .associate { it.string("kind") to it.string("expected") }
        assertEquals(EXPECTED_IDEMPOTENCY_KINDS, idempotencyKinds.keys)
        assertTrue(idempotencyKinds.getValue("migration").startsWith("conv:v1:migration:"))

        val identifiers = jsonArray("identifiers.json").objects().associateBy { it.string("wireName") }
        EXPECTED_COMMON_IDENTITY_FIELDS.filterNot { it in setOf("committedAt", "eventType", "occurredAt", "schemaVersion") }
            .forEach { assertTrue("identifier contract missing $it", identifiers.containsKey(it)) }

        val logEvents = jsonObject("log-contract.json").array("events").objects()
            .map { it.string("logEvent") }.toSet()
        assertTrue("CONVERSATION_MIGRATION_RESULT" in logEvents)
        assertTrue("TIMELINE_SYNC" in logEvents)
        assertTrue("LEGACY_DIRECT_WRITE_REJECTED" in logEvents)
        assertTrue("TASK_STATUS_PROJECTED" in logEvents)
    }

    @Test
    fun writeErrorsAndCommandErrorSseStayConsistentAndNonLeaking() {
        val errors = jsonArray("write-errors.json").objects().associateBy { it.string("errorCode") }
        assertEquals(EXPECTED_WRITE_ERRORS.keys, errors.keys)
        EXPECTED_WRITE_ERRORS.forEach { (code, expected) ->
            val error = errors.getValue(code)
            assertEquals("Unexpected HTTP status for $code", expected.first, error.int("httpStatus"))
            assertEquals("Unexpected retryability for $code", expected.second, error.get("retryable").asBoolean)
            assertEquals("NONE", error.string("sideEffect"))
            assertEquals("conversation_command_error", error.string("commandErrorSseEvent"))
        }

        assertTrue(errors.keys.none { code ->
            code.contains("UNAUTHORIZED") || code.contains("FORBIDDEN") || code.contains("ACCOUNT_NOT_OWNER")
        })
        val notFound = errors.getValue("CONVERSATION_WRITE_NOT_FOUND")
        assertEquals(
            setOf("errorCode", "httpStatus", "retryable", "sideEffect", "commandErrorSseEvent"),
            notFound.keySet(),
        )
        assertFalse(notFound.has("reason"))
        assertFalse(notFound.has("message"))
        assertFalse(notFound.has("accountId"))

        val envelope = jsonObject("write-command-error-sse.json")
        assertEquals("conversation_command_error", envelope.string("event"))
        val data = envelope.obj("data")
        val mappedError = errors.getValue(data.string("errorCode"))
        assertEquals(503, mappedError.int("httpStatus"))
        assertEquals(mappedError.get("retryable").asBoolean, data.get("retryable").asBoolean)
        assertEquals(mappedError.string("sideEffect"), data.string("sideEffect"))
        assertEquals(mappedError.string("commandErrorSseEvent"), envelope.string("event"))
        assertEquals(setOf("errorCode", "retryable", "sideEffect", "traceId"), data.keySet())
    }

    private fun resourceBytes(name: String): ByteArray {
        val path = "$RESOURCE_ROOT/$name"
        return requireNotNull(javaClass.classLoader?.getResourceAsStream(path)) {
            "Shared backend contract resource is missing: $path"
        }.use { it.readBytes() }
    }

    private fun jsonObject(name: String): JsonObject =
        JsonParser().parse(resourceBytes(name).toString(Charsets.UTF_8)).asJsonObject

    private fun jsonArray(name: String): JsonArray =
        JsonParser().parse(resourceBytes(name).toString(Charsets.UTF_8)).asJsonArray

    private fun JsonObject.string(name: String): String = get(name).asString
    private fun JsonObject.int(name: String): Int = get(name).asInt
    private fun JsonObject.long(name: String): Long = get(name).asLong
    private fun JsonObject.obj(name: String): JsonObject = getAsJsonObject(name)
    private fun JsonObject.array(name: String): JsonArray = getAsJsonArray(name)
    private fun JsonArray.strings(): List<String> = map(JsonElement::getAsString)
    private fun JsonArray.objects(): List<JsonObject> = map(JsonElement::getAsJsonObject)
    private fun ByteArray.sha256(): String = MessageDigest.getInstance("SHA-256").digest(this)
        .joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }

    companion object {
        private const val RESOURCE_ROOT = "conversation-history/v1"

        private val EXPECTED_EVENT_TYPES = setOf(
            "USER_TURN_ACCEPTED", "ASSISTANT_TURN_COMMITTED", "TOOL_REQUESTED", "TOOL_RESULT_RECORDED",
            "CALL_REQUESTED", "CALL_STARTED", "CALL_COMPLETED", "CALL_FAILED", "CALL_CANCELLED",
            "CALL_REJECTED", "CALL_OUTCOME_REPORTED", "CONVERSATION_INTERRUPTED", "CONVERSATION_RESUMED",
            "RUN_FAILED", "RUN_CANCELLED",
        )
        private val EXPECTED_COMMON_IDENTITY_FIELDS = setOf(
            "committedAt", "eventId", "eventType", "idempotencyKey", "occurredAt", "schemaVersion", "sequence", "sessionId",
        )
        private val EXPECTED_TIMELINE_ERRORS = setOf(
            "TIMELINE_NOT_FOUND", "TIMELINE_CURSOR_INVALID", "TIMELINE_CURSOR_AHEAD", "TIMELINE_SEQUENCE_GAP",
            "TIMELINE_LIMIT_INVALID", "TIMELINE_MIGRATION_INCOMPLETE", "TIMELINE_SCHEMA_UNSUPPORTED",
            "TIMELINE_UNAVAILABLE",
        )
        private val EXPECTED_IDEMPOTENCY_KINDS = setOf(
            "command", "event", "outbox", "physical-terminal", "outcome-report", "dispatch-failure", "migration",
            "reconciliation",
        )
        private val EXPECTED_WRITE_ERRORS = linkedMapOf(
            "CONVERSATION_WRITE_NOT_FOUND" to (404 to false),
            "CONVERSATION_SCOPE_MISMATCH" to (400 to false),
            "CONVERSATION_SCHEMA_INVALID" to (422 to false),
            "CONVERSATION_PAYLOAD_INVALID" to (422 to false),
            "CONVERSATION_IDEMPOTENCY_CONFLICT" to (409 to false),
            "CONVERSATION_SEQUENCE_CONFLICT" to (409 to true),
            "CONVERSATION_APPEND_ROLLED_BACK" to (503 to true),
            "CONVERSATION_APPEND_UNAVAILABLE" to (503 to true),
        )
        private val PINNED_SHA256 = linkedMapOf(
            "event-types.json" to "70dacb5eeb9eb7f89a4bf934186fa4cb155c0d150c6ed90c5ed7f33f22e33b06",
            "idempotency-vectors.json" to "e5d82d0b52a1dfb33cd68f0944895e95aa567d46d06c9ca48366d0b4c95b5448",
            "identifiers.json" to "fca273b5cf5cba37754e9790d97c6b3764b5839265d4ca5f823f9d5cc0230c3b",
            "log-contract.json" to "52940ae2a60d4e7d336d33a450c6fbbe407dcfe1126285a998cead8dc149ad65",
            "outbox-transitions.json" to "d19f8cb2f98eed1c6036ae0f003927abc0552abc6d37a1f63c7a4881fa0ac278",
            "payload-schemas.json" to "ac23f6637ec75da5e67ebb7cf321383029664565ae38d1bbf6f830f9e93abaa1",
            "timeline-committed-sse.json" to "75cff48268e01273ddbab74428942412d7000ad122c003ed60ea03e6e7b3f20f",
            "timeline-errors.json" to "ea71f2554f10cafbed32678831ec75dc6bd9513924e1b92884d294ba5b08ef63",
            "timeline-page.json" to "3de338f0b0ebaf39591db83f4687b7237320ba07f5257377bb4dac449e3e8e43",
            "write-command-error-sse.json" to "87723e0da9d0e0c3ebbdedb4e1baea1e1f7078b0dd4f7c44a8d60df6d4ef53e5",
            "write-errors.json" to "8147325402e055d7feb07033f12af1f14c4a2d2dd4bccf54edf3b44bc06943f2",
        )
    }
}
