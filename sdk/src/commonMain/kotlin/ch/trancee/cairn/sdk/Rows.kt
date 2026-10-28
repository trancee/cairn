package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Event

/** The core's durable rows (ADR 0034 §1): [LinkDriver] commits and restores them. */
interface Rows {
    /** Stores the row actions among [actions] in one transaction; other actions are ignored. */
    fun commit(actions: List<Action>)

    /** Every stored row, in key order. */
    fun restore(): Restored
}

/** A restore; [reset] means unreadable storage was wiped first (ADR 0035 §5). */
data class Restored(val event: Event.Restore, val reset: Boolean = false)

/**
 * The platform's AES-256-GCM under the installation's master key (ADR 0035 §1). The key never
 * leaves the platform implementation.
 */
interface RowSealer {
    /** Returns `nonce(12) ‖ ciphertext ‖ tag(16)` with a fresh random nonce. */
    fun seal(aad: ByteArray, plaintext: ByteArray): ByteArray

    /** The plaintext, or `null` if [sealed] does not authenticate under [aad]. */
    fun open(aad: ByteArray, sealed: ByteArray): ByteArray?
}
