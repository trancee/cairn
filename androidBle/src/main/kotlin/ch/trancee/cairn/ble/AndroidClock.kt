package ch.trancee.cairn.ble

import android.os.SystemClock
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.sdk.ClockSource

/** Monotonic milliseconds since boot, deep sleep included, and wall-clock seconds (ADR 0022 §2). */
object AndroidClock : ClockSource {
    override fun now(): Clock =
        Clock(SystemClock.elapsedRealtime().toULong(), (System.currentTimeMillis() / 1000).toULong())
}
