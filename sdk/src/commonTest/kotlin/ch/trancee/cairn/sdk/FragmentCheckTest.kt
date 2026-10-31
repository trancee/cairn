package ch.trancee.cairn.sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class FragmentCheckTest {
    @Test
    fun theCheckMatchesTheStandardTestVector() {
        val value = "123456789".encodeToByteArray() + byteArrayOf(0x29, 0xb1.toByte())

        val intact = FragmentCheck.intact(value)

        assertTrue(intact)
    }

    @Test
    fun aValueWithAnyByteChangedFailsItsCheck() {
        val value = "123456789".encodeToByteArray() + byteArrayOf(0x29, 0xb1.toByte())

        val failures = value.indices.count { index ->
            val corrupted = value.copyOf().also { it[index] = (it[index].toInt() xor 0x10).toByte() }
            !FragmentCheck.intact(corrupted)
        }

        assertEquals(value.size, failures)
    }

    @Test
    fun aValueTooShortForAHeaderAndCheckIsNotIntact() {
        val values = listOf(byteArrayOf(), byteArrayOf(0x30), byteArrayOf(-1, -1))

        val intact = values.map(FragmentCheck::intact)

        assertFalse(intact.any { it })
    }
}
