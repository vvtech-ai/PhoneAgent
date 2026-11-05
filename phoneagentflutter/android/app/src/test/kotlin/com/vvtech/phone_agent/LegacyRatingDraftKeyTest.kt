package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Test

class LegacyRatingDraftKeyTest {
    @Test fun fixedV65NullDelimitedSha256() {
        assertEquals("task_rating_draft_01d0a57b6dbeae051e2b2a5c7aece28cf9c0d666d1e0ef8914e2224899c07cd2",
            LegacyRatingDraftKey.key("phone-18800000000", "SINGLE", "synthetic-task"))
        val keys = listOf(
            LegacyRatingDraftKey.key("a", "BATCH", "bc"),
            LegacyRatingDraftKey.key("a", "SINGLE", "bc"),
            LegacyRatingDraftKey.key("ab", "SINGLE", "c"),
            LegacyRatingDraftKey.key("a", "SINGLE", "another")
        )
        assertEquals(4, keys.toSet().size)
    }

    @Test fun rejectsMissingGuestAndDelimiterInjection() {
        for (account in listOf("", "guest", "a\u0000b", "a/b", "x".repeat(257))) {
            assertThrows(IllegalArgumentException::class.java) {
                LegacyRatingDraftKey.key(account, "SINGLE", "task")
            }
        }
        for (value in listOf("", " ", "x\u0000y", "x\ny", "x".repeat(257))) {
            assertThrows(IllegalArgumentException::class.java) {
                LegacyRatingDraftKey.key("a", value, "task")
            }
            assertThrows(IllegalArgumentException::class.java) {
                LegacyRatingDraftKey.key("a", "SINGLE", value)
            }
        }
    }

    @Test fun boundsUtf8WithoutTruncation() {
        assertNull(LegacyRatingDraftKey.bounded(null))
        val valid = "x".repeat(65536)
        assertEquals(valid, LegacyRatingDraftKey.bounded(valid))
        assertThrows(IllegalArgumentException::class.java) {
            LegacyRatingDraftKey.bounded("x".repeat(65537))
        }
        assertThrows(IllegalArgumentException::class.java) {
            LegacyRatingDraftKey.bounded("界".repeat(23000))
        }
    }
}
