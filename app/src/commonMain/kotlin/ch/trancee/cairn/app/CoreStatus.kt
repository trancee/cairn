package ch.trancee.cairn.app

import ch.trancee.cairn.ffi.IncomingObject
import ch.trancee.cairn.ffi.ObjectKind
import ch.trancee.cairn.ffi.WireException
import ch.trancee.cairn.ffi.decodeLengthPrefixed
import ch.trancee.cairn.ffi.encodeLengthPrefixed

/** Exercises each kind of Rust core call the reference app depends on and summarizes the outcome. */
fun coreStatus(): String {
    val field = decodeLengthPrefixed(encodeLengthPrefixed("cairn".encodeToByteArray())).value.decodeToString()
    val rejected = try {
        decodeLengthPrefixed(byteArrayOf(0, 2, 1))
        "none"
    } catch (error: WireException.Truncated) {
        "Truncated"
    }
    val incoming = IncomingObject(0u, ObjectKind.CIPHERTEXT)
    incoming.acceptChunk(0u, ObjectKind.CIPHERTEXT, 0u, ByteArray(600))
    val progress = incoming.nextOffset()
    incoming.close()
    val closed = try {
        incoming.nextOffset()
        false
    } catch (error: IllegalStateException) {
        true
    }
    return "field=$field rejected=$rejected progress=$progress closed=$closed"
}
