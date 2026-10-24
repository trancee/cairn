package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.CairnCore
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.Event

/** The protocol core as the [LinkDriver] sees it: [CoreEngine] in apps, a fake in unit tests. */
interface Engine {
    fun handle(clock: Clock, event: Event): List<Action>

    fun contacts(): List<ContactInfo>

    fun beacon(unixS: ULong): ByteArray

    fun close()
}

/** [Engine] backed by the Rust `CairnCore`. */
class CoreEngine : Engine {
    private val core = CairnCore()

    override fun handle(clock: Clock, event: Event): List<Action> = core.handle(clock, event)

    override fun contacts(): List<ContactInfo> = core.contacts()

    override fun beacon(unixS: ULong): ByteArray = core.beacon(unixS)

    override fun close() = core.close()
}

/** Platform BLE links, addressed by the ids [LinkDriver.linkUp] returned (ADR 0023 §2). */
interface Radio {
    /** Writes or notifies one ATT value; the platform calls [LinkDriver.sent] when it can take the next. */
    fun send(link: ULong, fragment: ByteArray)

    /** Closes the link; the platform still reports [LinkDriver.linkDown]. */
    fun disconnect(link: ULong)
}

/** Platform timers; expiry calls [LinkDriver.timerFired]. */
interface Timers {
    fun schedule(timer: ULong, atMonoMs: ULong)

    fun cancel(timer: ULong)
}

/** Supplies the monotonic and wall-clock time stamped on every event (ADR 0022 §2). */
fun interface ClockSource {
    fun now(): Clock
}
