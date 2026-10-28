package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Clock

/**
 * The platform self-test of [rows] (ADR 0035): restores a core from them, commits the rows the
 * core emits and reads the device row back. Returns `storage=<new|restored|reset> device=<stored|missing>`.
 */
fun checkStorage(rows: Rows, clock: Clock): String {
    val restored = rows.restore()
    val state = when {
        restored.reset -> "reset"
        restored.event.device == null -> "new"
        else -> "restored"
    }
    val engine = CoreEngine()
    try {
        rows.commit(engine.handle(clock, restored.event))
    } finally {
        engine.close()
    }
    val device = if (rows.restore().event.device != null) "stored" else "missing"
    return "storage=$state device=$device"
}
