package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.GattRole
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Two [LinkDriver]s over real cores, joined by an in-memory radio. Deliveries are queued and
 * pumped, as platform callbacks are posted to the driver's thread.
 */
private class Air(mtu: UShort) {
    private val pending = ArrayDeque<() -> Unit>()
    private val clock = ClockSource { Clock(monoMs = 1_000uL, unixS = 1_761_177_600uL) }
    val notices = listOf(mutableListOf<Notice>(), mutableListOf())
    private val peerLink = mutableMapOf<Pair<Int, ULong>, ULong>()
    val drivers: List<LinkDriver> = (0..1).map { side ->
        LinkDriver(::CoreEngine, AirRadio(side), NoTimers, clock) { notices[side] += it }
    }

    private inner class AirRadio(private val side: Int) : Radio {
        override fun send(link: ULong, fragment: ByteArray) {
            val copy = fragment.copyOf()
            pending.addLast { drivers[1 - side].received(peerLink.getValue(side to link), copy) }
            pending.addLast { drivers[side].sent(link) }
        }

        override fun disconnect(link: ULong) {
            val peer = peerLink.getValue(side to link)
            pending.addLast { drivers[side].linkDown(link) }
            pending.addLast { drivers[1 - side].linkDown(peer) }
        }
    }

    private object NoTimers : Timers {
        override fun schedule(timer: ULong, atMonoMs: ULong) = Unit

        override fun cancel(timer: ULong) = Unit
    }

    init {
        drivers.forEach(LinkDriver::start)
        val central = drivers[0].linkUp(GattRole.CENTRAL, mtu, byteArrayOf(1))
        val peripheral = drivers[1].linkUp(GattRole.PERIPHERAL, mtu, byteArrayOf(0))
        peerLink[0 to central] = peripheral
        peerLink[1 to peripheral] = central
        drivers[0].beaconRead(central, drivers[1].beacon())
        pump()
    }

    fun pump() {
        while (pending.isNotEmpty()) pending.removeFirst()()
    }

    fun close() = drivers.forEach(LinkDriver::close)
}

class DriverLoopbackTest {
    private val opened = mutableListOf<Air>()

    private fun air(mtu: UShort) = Air(mtu).also { opened += it }

    @AfterTest
    fun closeCores() = opened.forEach(Air::close)

    @Test
    fun twoDriversPairAndChatAtTheSmallestMtu() {
        val air = air(23u)
        val contact = air.drivers[0].contacts().single().id

        air.drivers[0].sendChat(contact, "grüezi über BLE")
        air.pump()

        val received = air.notices[1].filterIsInstance<Notice.ChatReceived>().map { it.text }
        assertEquals(listOf("grüezi über BLE"), received)
        assertEquals(1, air.notices[0].filterIsInstance<Notice.ChatSent>().size)
        assertEquals(listOf(1, 1), air.drivers.map { it.contacts().size })
        assertTrue(air.drivers.all { driver -> driver.links().single().fragmentsOut > 1 })
    }
}
