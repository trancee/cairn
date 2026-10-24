package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.CoreException
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.Verification
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

private val BLOB = Persisted(byteArrayOf(1, 2, 3), 1u)
private val CONTACT = ContactInfo(7uL, "", Verification.UNVERIFIED)

/** Scripted [Engine]: [respond] maps each event to actions or throws. */
private class FakeEngine(var respond: (Event) -> List<Action> = { emptyList() }) : Engine {
    val events = mutableListOf<List<Any?>>()
    val clocks = mutableListOf<Clock>()
    var contactsResult: () -> List<ContactInfo> = { listOf(CONTACT) }
    var beaconResult: (ULong) -> ByteArray = { unixS -> byteArrayOf(unixS.toByte()) }
    var closed = false

    override fun handle(clock: Clock, event: Event): List<Action> {
        clocks += clock
        events += key(event)
        return respond(event)
    }

    override fun contacts(): List<ContactInfo> = contactsResult()

    override fun beacon(unixS: ULong): ByteArray = beaconResult(unixS)

    override fun close() {
        closed = true
    }
}

private class FakeRadio : Radio {
    val sent = mutableListOf<Pair<ULong, List<Byte>>>()
    val disconnected = mutableListOf<ULong>()

    override fun send(link: ULong, fragment: ByteArray) {
        sent += link to fragment.toList()
    }

    override fun disconnect(link: ULong) {
        disconnected += link
    }
}

private class FakeTimers : Timers {
    val scheduled = mutableListOf<Pair<ULong, ULong>>()
    val cancelled = mutableListOf<ULong>()

    override fun schedule(timer: ULong, atMonoMs: ULong) {
        scheduled += timer to atMonoMs
    }

    override fun cancel(timer: ULong) {
        cancelled += timer
    }
}

/** A started driver over fakes; [engines] lists every engine the driver created, in order. */
private class Rig {
    val engines = mutableListOf<FakeEngine>()
    val radio = FakeRadio()
    val timers = FakeTimers()
    val notices = mutableListOf<Notice>()
    var now = Clock(monoMs = 1_000uL, unixS = 1_761_177_600uL)
    val driver = LinkDriver(
        newEngine = { FakeEngine { if (it is Event.Restore) listOf(Action.Persist(BLOB)) else emptyList() }.also { engines += it } },
        radio = radio,
        timers = timers,
        clock = { now },
        listener = { notices += it },
    )
    val engine get() = engines.last()

    init {
        driver.start()
    }

    /** Makes the current engine answer [trigger] with [actions] once. */
    fun answer(trigger: Event, vararg actions: Action) {
        val previous = engine.respond
        engine.respond = { if (key(it) == key(trigger)) actions.toList() else previous(it) }
    }
}

private fun bytes(size: Int, fill: Int = 0) = ByteArray(size) { fill.toByte() }

/** Generated events hold byte arrays, which data-class equality compares by reference. */
private fun key(event: Event): List<Any?> = when (event) {
    is Event.Restore -> listOf("Restore", event.state?.blob?.toList(), event.state?.version)
    is Event.LinkUp -> listOf("LinkUp", event.link, event.gattRole, event.mtu, event.address.toList())
    is Event.MtuChanged -> listOf("MtuChanged", event.link, event.mtu)
    is Event.BeaconRead -> listOf("BeaconRead", event.link, event.beacon.toList())
    is Event.Received -> listOf("Received", event.link, event.fragment.toList())
    is Event.LinkDown -> listOf("LinkDown", event.link)
    is Event.TimerFired -> listOf("TimerFired", event.timer)
    is Event.SendChat -> listOf("SendChat", event.contact, event.text)
}

private fun keys(vararg events: Event) = events.map(::key)

class LinkDriverTest {
    @Test
    fun startRestoresAFreshCoreAndKeepsItsBlob() {
        val rig = Rig()

        assertEquals(keys(Event.Restore(null)), rig.engine.events)
        assertEquals(BLOB, rig.driver.persisted)
    }

    @Test
    fun linkUpAllocatesIncreasingIdsAndStampsTheClock() {
        val rig = Rig()

        val first = rig.driver.linkUp(GattRole.CENTRAL, 185u, byteArrayOf(9))
        rig.now = Clock(monoMs = 2_000uL, unixS = 1_761_177_601uL)
        val second = rig.driver.linkUp(GattRole.PERIPHERAL, 23u, byteArrayOf(8))

        assertEquals(listOf(1uL, 2uL), listOf(first, second))
        assertEquals(
            keys(Event.LinkUp(1uL, GattRole.CENTRAL, 185u, byteArrayOf(9)), Event.LinkUp(2uL, GattRole.PERIPHERAL, 23u, byteArrayOf(8))),
            rig.engine.events.drop(1),
        )
        assertEquals(listOf(1_000uL, 1_000uL, 2_000uL), rig.engine.clocks.map { it.monoMs })
        assertEquals(
            listOf(LinkStats(1uL, GattRole.CENTRAL, 185u, 1_000uL, 0, 0, 0, 0), LinkStats(2uL, GattRole.PERIPHERAL, 23u, 2_000uL, 0, 0, 0, 0)),
            rig.driver.links(),
        )
    }

    @Test
    fun linkEventsReachTheCoreAndTheCounters() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())

        rig.driver.mtuChanged(link, 247u)
        rig.driver.beaconRead(link, bytes(8))
        rig.driver.received(link, bytes(20))
        rig.driver.received(link, bytes(5))

        assertEquals(
            keys(Event.MtuChanged(link, 247u), Event.BeaconRead(link, bytes(8)), Event.Received(link, bytes(20)), Event.Received(link, bytes(5))),
            rig.engine.events.drop(2),
        )
        assertEquals(LinkStats(link, GattRole.CENTRAL, 247u, 1_000uL, 0, 0, 2, 25), rig.driver.links().single())
    }

    @Test
    fun eventsForAForgottenLinkStillReachTheCore() {
        val rig = Rig()

        rig.driver.mtuChanged(5uL, 100u)
        rig.driver.received(5uL, bytes(3))

        assertEquals(keys(Event.MtuChanged(5uL, 100u), Event.Received(5uL, bytes(3))), rig.engine.events.drop(1))
        assertEquals(emptyList(), rig.driver.links())
    }

    @Test
    fun fragmentsLeaveOneAtATimeInOrder() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        rig.answer(Event.Received(link, bytes(1)), Action.Send(link, bytes(2, 1)), Action.Send(link, bytes(3, 2)), Action.Send(link, bytes(4, 3)))

        rig.driver.received(link, bytes(1))
        val afterBatch = rig.radio.sent.size
        rig.driver.sent(link)
        rig.driver.sent(link)
        rig.driver.sent(link)

        assertEquals(1, afterBatch)
        assertEquals(listOf(bytes(2, 1), bytes(3, 2), bytes(4, 3)).map { link to it.toList() }, rig.radio.sent)
        assertEquals(LinkStats(link, GattRole.CENTRAL, 23u, 1_000uL, 3, 9, 1, 1), rig.driver.links().single())
    }

    @Test
    fun aConfirmedQueueSendsTheNextBatchAtOnce() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.PERIPHERAL, 23u, byteArrayOf())
        rig.answer(Event.Received(link, bytes(1)), Action.Send(link, bytes(2)))
        rig.driver.received(link, bytes(1))
        rig.driver.sent(link)

        rig.driver.received(link, bytes(1))

        assertEquals(2, rig.radio.sent.size)
    }

    @Test
    fun linksQueueIndependently() {
        val rig = Rig()
        val first = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        val second = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        rig.answer(Event.SendChat(7uL, "hi"), Action.Send(first, bytes(1)), Action.Send(second, bytes(2)), Action.Send(first, bytes(3)))

        rig.driver.sendChat(7uL, "hi")

        assertEquals(listOf(first to bytes(1).toList(), second to bytes(2).toList()), rig.radio.sent)
    }

    @Test
    fun overflowingTheQueueDisconnectsTheLinkOnce() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        val half = LinkDriver.MAX_QUEUED_BYTES / 2
        rig.answer(
            Event.Received(link, bytes(1)),
            Action.Send(link, bytes(half)),
            Action.Send(link, bytes(half)),
            Action.Send(link, bytes(1)),
            Action.Send(link, bytes(1)),
            Action.Disconnect(link),
        )

        rig.driver.received(link, bytes(1))
        rig.driver.sent(link)

        assertEquals(1, rig.radio.sent.size)
        assertEquals(listOf(link), rig.radio.disconnected)
    }

    @Test
    fun aFullButNotOverflowingQueueStaysUp() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        val half = LinkDriver.MAX_QUEUED_BYTES / 2
        rig.answer(Event.Received(link, bytes(1)), Action.Send(link, bytes(half)), Action.Send(link, bytes(half)))

        rig.driver.received(link, bytes(1))
        rig.driver.sent(link)

        assertEquals(2, rig.radio.sent.size)
        assertEquals(emptyList(), rig.radio.disconnected)
    }

    @Test
    fun disconnectDropsQueuedFragments() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        rig.answer(Event.Received(link, bytes(1)), Action.Send(link, bytes(1)), Action.Send(link, bytes(2)), Action.Disconnect(link))

        rig.driver.received(link, bytes(1))
        rig.driver.sent(link)

        assertEquals(listOf(link to bytes(1).toList()), rig.radio.sent)
        assertEquals(listOf(link), rig.radio.disconnected)
    }

    @Test
    fun linkDownForgetsTheLink() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        rig.answer(Event.LinkDown(link), Action.Send(link, bytes(1)), Action.Disconnect(link))

        rig.driver.linkDown(link)
        rig.driver.sent(link)

        assertEquals(key(Event.LinkDown(link)), rig.engine.events.last())
        assertEquals(emptyList(), rig.driver.links())
        assertEquals(emptyList(), rig.radio.sent)
        assertEquals(emptyList(), rig.radio.disconnected)
    }

    @Test
    fun timersAreScheduledCancelledAndFiredOnlyWhileActive() {
        val rig = Rig()
        rig.answer(Event.SendChat(7uL, "a"), Action.SetTimer(3uL, 6_000uL), Action.SetTimer(4uL, 7_000uL), Action.CancelTimer(4uL))

        rig.driver.sendChat(7uL, "a")
        rig.driver.timerFired(4uL)
        rig.driver.timerFired(3uL)
        rig.driver.timerFired(3uL)

        assertEquals(listOf(3uL to 6_000uL, 4uL to 7_000uL), rig.timers.scheduled)
        assertEquals(listOf(4uL), rig.timers.cancelled)
        assertEquals(keys(Event.SendChat(7uL, "a"), Event.TimerFired(3uL)), rig.engine.events.drop(1))
    }

    @Test
    fun appActionsBecomeNotices() {
        val rig = Rig()
        rig.answer(
            Event.SendChat(7uL, "a"),
            Action.ContactAdded(7uL),
            Action.ChatReceived(7uL, 1u, "hey"),
            Action.ChatSent(7uL, 2u),
            Action.ChatRejected(7uL, ChatRejection.TOO_LONG),
        )

        rig.driver.sendChat(7uL, "a")

        assertEquals(
            listOf(
                Notice.ContactsChanged(listOf(CONTACT)),
                Notice.ChatReceived(7uL, 1u, "hey"),
                Notice.ChatSent(7uL, 2u),
                Notice.ChatRejected(7uL, ChatRejection.TOO_LONG),
            ),
            rig.notices,
        )
    }

    @Test
    fun persistKeepsTheLatestBlob() {
        val rig = Rig()
        val later = Persisted(byteArrayOf(4), 1u)
        rig.answer(Event.SendChat(7uL, "a"), Action.Persist(later))

        rig.driver.sendChat(7uL, "a")

        assertEquals(later, rig.driver.persisted)
    }

    @Test
    fun queriesUseTheCurrentClockAndCore() {
        val rig = Rig()
        rig.now = Clock(monoMs = 5uL, unixS = 300uL)

        assertContentEquals(byteArrayOf(300.toByte()), rig.driver.beacon())
        assertEquals(listOf(CONTACT), rig.driver.contacts())
    }

    @Test
    fun aCryptoFailureDropsTheBatchAndIsReported() {
        val rig = Rig()
        val link = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        rig.engine.respond = { throw CoreException.Crypto() }

        rig.driver.received(link, bytes(1))

        assertEquals(listOf<Notice>(Notice.Fault(FaultKind.CRYPTO)), rig.notices)
        assertEquals(1, rig.driver.links().size)
        assertEquals(1, rig.engines.size)
    }

    @Test
    fun aPoisonedCoreIsReplacedFromTheLastBlob() {
        val rig = Rig()
        val first = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())
        val second = rig.driver.linkUp(GattRole.PERIPHERAL, 23u, byteArrayOf())
        rig.answer(Event.SendChat(7uL, "a"), Action.SetTimer(3uL, 9_000uL))
        rig.driver.sendChat(7uL, "a")
        val poisoned = rig.engine
        poisoned.respond = { throw CoreException.Poisoned() }

        rig.driver.received(first, bytes(1))
        rig.driver.timerFired(3uL)
        val third = rig.driver.linkUp(GattRole.CENTRAL, 23u, byteArrayOf())

        assertTrue(poisoned.closed)
        assertEquals(listOf(first, second), rig.radio.disconnected)
        assertEquals(listOf(3uL), rig.timers.cancelled)
        assertEquals(keys(Event.Restore(BLOB), Event.LinkUp(third, GattRole.CENTRAL, 23u, byteArrayOf())), rig.engine.events)
        assertEquals(3uL, third)
        assertEquals(listOf<Notice>(Notice.Fault(FaultKind.POISONED)), rig.notices)
    }

    @Test
    fun poisonedQueriesAnswerFromTheReplacement() {
        val rig = Rig()
        rig.engine.beaconResult = { throw CoreException.Poisoned() }

        val beacon = rig.driver.beacon()
        rig.engine.contactsResult = { throw CoreException.Poisoned() }
        val contacts = rig.driver.contacts()

        assertContentEquals(byteArrayOf(1_761_177_600uL.toByte()), beacon)
        assertEquals(listOf(CONTACT), contacts)
        assertEquals(3, rig.engines.size)
    }

    @Test
    fun contractViolationsPropagate() {
        val rig = Rig()
        rig.engine.respond = { throw CoreException.UnknownContact() }

        assertFailsWith<CoreException.UnknownContact> { rig.driver.sendChat(9uL, "x") }
    }

    @Test
    fun closeClosesTheCore() {
        val rig = Rig()

        rig.driver.close()

        assertTrue(rig.engine.closed)
    }
}
