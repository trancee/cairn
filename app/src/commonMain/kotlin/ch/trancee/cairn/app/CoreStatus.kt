package ch.trancee.cairn.app

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.CairnCore
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.CoreException
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole

private val CLOCK = Clock(monoMs = 1_000uL, unixS = 1_761_177_600uL)

/** What [coreStatus] returns when every check passes; each platform's self-test compares against it. */
const val EXPECTED_CORE_STATUS = "paired=1+1 chat=hello rejected=NotRestored closed=true"

/**
 * Pairs two in-process cores over a memory loopback, sends one chat and checks the typed error and
 * post-close paths, then summarizes the outcome.
 */
fun coreStatus(): String {
    val cores = listOf(CairnCore(), CairnCore())
    try {
        val received = mutableListOf<String>()
        fun deliver(from: Int, event: Event) {
            val stack = ArrayDeque(listOf(from to event))
            while (stack.isNotEmpty()) {
                val (device, next) = stack.removeLast()
                val actions = cores[device].handle(CLOCK, next)
                for (action in actions.asReversed()) {
                    when (action) {
                        is Action.Send -> stack.addLast(1 - device to Event.Received(action.link xor 1uL, action.fragment))
                        is Action.ChatReceived -> received += action.text
                        else -> Unit
                    }
                }
            }
        }
        val rejected = try {
            cores[0].beacon(CLOCK.unixS)
            "none"
        } catch (error: CoreException.NotRestored) {
            "NotRestored"
        }
        cores.indices.forEach { deliver(it, Event.Restore(null, emptyList(), emptyList(), emptyList())) }
        deliver(0, Event.LinkUp(0uL, GattRole.CENTRAL, 185u, byteArrayOf(1)))
        deliver(1, Event.LinkUp(1uL, GattRole.PERIPHERAL, 185u, byteArrayOf(0)))
        deliver(0, Event.BeaconRead(0uL, cores[1].beacon(CLOCK.unixS)))
        val paired = cores.map { it.contacts().size }
        deliver(0, Event.SendChat(cores[0].contacts().single().id, "hello"))
        return "paired=${paired.joinToString("+")} chat=${received.joinToString()} rejected=$rejected " +
            "closed=${closedCoreRejectsCalls()}"
    } finally {
        cores.forEach(CairnCore::close)
    }
}

private fun closedCoreRejectsCalls(): Boolean {
    val core = CairnCore()
    core.close()
    return try {
        core.contacts()
        false
    } catch (error: IllegalStateException) {
        true
    }
}
