package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.ChunkOutcome
import ch.trancee.cairn.ffi.IncomingObject
import ch.trancee.cairn.ffi.ObjectKind
import ch.trancee.cairn.ffi.TransferException
import ch.trancee.cairn.ffi.WireException
import ch.trancee.cairn.ffi.decodeLeb128
import ch.trancee.cairn.ffi.decodeLengthPrefixed
import ch.trancee.cairn.ffi.encodeLeb128
import ch.trancee.cairn.ffi.encodeLengthPrefixed
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class CoreBindingTest {
    @Test
    fun lengthPrefixedFieldRoundTripsAcrossTheBoundary() {
        val encoded = encodeLengthPrefixed("cairn".encodeToByteArray())

        val decoded = decodeLengthPrefixed(encoded + 0xff.toByte())

        assertContentEquals(byteArrayOf(0, 5) + "cairn".encodeToByteArray(), encoded)
        assertEquals("cairn", decoded.value.decodeToString())
        assertEquals(7u, decoded.consumed)
    }

    @Test
    fun truncatedFieldThrowsTypedException() {
        val input = byteArrayOf(0, 2, 1)

        assertFailsWith<WireException.Truncated> { decodeLengthPrefixed(input) }
    }

    @Test
    fun leb128RoundTripsAndRejectsNonMinimalInput() {
        val encoded = encodeLeb128(624_485u)

        val decoded = decodeLeb128(encoded)

        assertContentEquals(byteArrayOf(0xe5.toByte(), 0x8e.toByte(), 0x26), encoded)
        assertEquals(624_485u, decoded.value)
        assertFailsWith<WireException.NonMinimal> { decodeLeb128(byteArrayOf(0x80.toByte(), 0)) }
    }

    @Test
    fun incomingObjectKeepsRustStateUntilClosed() {
        val incoming = IncomingObject(3u, ObjectKind.CIPHERTEXT)

        val first = incoming.acceptChunk(3u, ObjectKind.CIPHERTEXT, 0u, ByteArray(600) { 1 })
        val last = incoming.acceptChunk(3u, ObjectKind.CIPHERTEXT, 600u, ByteArray(488) { 2 })
        val completed = incoming.completed()
        incoming.close()

        assertEquals(ChunkOutcome.APPENDED, first)
        assertEquals(ChunkOutcome.APPENDED, last)
        assertEquals(1088, completed?.size)
        assertFailsWith<IllegalStateException> { incoming.nextOffset() }
    }

    @Test
    fun rejectedChunkThrowsTypedExceptionWithoutProgress() {
        val incoming = IncomingObject(4u, ObjectKind.ENCAPSULATION_KEY)

        assertFailsWith<TransferException.Invalid> {
            incoming.acceptChunk(5u, ObjectKind.ENCAPSULATION_KEY, 0u, byteArrayOf(1))
        }

        assertEquals(0u, incoming.nextOffset())
        assertNull(incoming.completed())
        incoming.close()
    }
}
