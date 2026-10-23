package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.CairnCore
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.CoreException
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.Verification
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private val CLOCK = Clock(monoMs = 1_000uL, unixS = 1_761_177_600uL)

/** One core and every action it returned, in order. */
private class Device(state: Persisted?) {
    val core = CairnCore()
    val log = mutableListOf<Action>()

    init {
        log += core.handle(CLOCK, Event.Restore(state))
    }

    val persisted: Persisted?
        get() = log.filterIsInstance<Action.Persist>().lastOrNull()?.state

    val chats: List<Pair<ULong, String>>
        get() = log.filterIsInstance<Action.ChatReceived>().map { it.contact to it.text }
}

/** Two cores joined in memory; device 0's link `n` is device 1's link `n xor 1`. */
private class Loopback(states: List<Persisted?> = listOf(null, null)) {
    val devices = states.map(::Device)

    fun deliver(from: Int, event: Event) {
        val stack = ArrayDeque(listOf(from to event))
        while (stack.isNotEmpty()) {
            val (device, next) = stack.removeLast()
            val actions = devices[device].core.handle(CLOCK, next)
            devices[device].log += actions
            val peer = 1 - device
            for (action in actions.asReversed()) {
                when (action) {
                    is Action.Send -> stack.addLast(peer to Event.Received(action.link xor 1uL, action.fragment))
                    is Action.Disconnect -> stack.addLast(peer to Event.LinkDown(action.link xor 1uL))
                    else -> Unit
                }
            }
        }
    }

    fun connect(link: ULong) {
        deliver(0, Event.LinkUp(link, GattRole.CENTRAL, 185u, "device-1".encodeToByteArray()))
        deliver(1, Event.LinkUp(link xor 1uL, GattRole.PERIPHERAL, 185u, "device-0".encodeToByteArray()))
        deliver(0, Event.BeaconRead(link, devices[1].core.beacon(CLOCK.unixS)))
    }

    fun disconnect(link: ULong) {
        deliver(0, Event.LinkDown(link))
        deliver(1, Event.LinkDown(link xor 1uL))
    }

    fun close() = devices.forEach { it.core.close() }
}

class CoreLoopbackTest {
    private val opened = mutableListOf<Loopback>()

    private fun loopback(states: List<Persisted?> = listOf(null, null)) = Loopback(states).also { opened += it }

    @AfterTest
    fun closeCores() = opened.forEach(Loopback::close)

    @Test
    fun twoCoresPairAndChatThroughTheBindings() {
        val net = loopback().apply { connect(2uL) }
        val (a, b) = net.devices.map { it.core.contacts().single().id }

        net.deliver(0, Event.SendChat(a, "grüezi"))

        assertEquals(listOf(b to "grüezi"), net.devices[1].chats)
        assertEquals(listOf(ContactInfo(b, "", Verification.UNVERIFIED)), net.devices[1].core.contacts())
    }

    @Test
    fun restoredCoresResumeOnANewLink() {
        val first = loopback().apply {
            connect(2uL)
            disconnect(2uL)
        }
        val net = loopback(first.devices.map { it.persisted })
        val (a, b) = net.devices.map { it.core.contacts().single().id }

        net.connect(4uL)
        net.deliver(0, Event.SendChat(a, "again"))

        assertEquals(listOf(b to "again"), net.devices[1].chats)
    }

    @Test
    fun callerContractViolationThrowsTypedException() {
        val core = CairnCore()

        assertFailsWith<CoreException.NotRestored> { core.beacon(CLOCK.unixS) }
        core.close()
    }

    @Test
    fun closedCoreRejectsCalls() {
        val core = CairnCore()
        core.close()

        assertFailsWith<IllegalStateException> { core.contacts() }
    }
}
