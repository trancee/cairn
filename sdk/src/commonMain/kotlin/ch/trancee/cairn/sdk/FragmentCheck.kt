package ch.trancee.cairn.sdk

/**
 * The check that ends every GATT fragment (ADR 0042, spec §4.3): CRC-16/CCITT-FALSE over the
 * header and body, big-endian. The core adds and verifies it; this copy lets a radio's GATT server
 * refuse a corrupted write before answering it, so the central writes it again.
 */
object FragmentCheck {
    /** The ATT error a GATT server answers a write with when its check fails. */
    const val CHECK_FAILED: Int = 0x9E

    /** How many times a central writes a fragment again after its check failed. */
    const val RESENDS: Int = 3

    private const val HEADER_AND_CHECK = 3

    /** Whether [value] holds a header and check, and the check matches. */
    fun intact(value: ByteArray): Boolean {
        if (value.size < HEADER_AND_CHECK) return false
        val end = value.size - 2
        val check = ((value[end].toInt() and 0xff) shl 8) or (value[end + 1].toInt() and 0xff)
        return crc16(value, end) == check
    }

    // Polynomial 0x1021, initial value 0xFFFF, no reflection, no final XOR.
    private fun crc16(bytes: ByteArray, length: Int): Int {
        var crc = 0xffff
        for (index in 0 until length) {
            crc = crc xor ((bytes[index].toInt() and 0xff) shl 8)
            repeat(8) {
                crc = if (crc and 0x8000 == 0) crc shl 1 else (crc shl 1) xor 0x1021
            }
            crc = crc and 0xffff
        }
        return crc
    }
}
