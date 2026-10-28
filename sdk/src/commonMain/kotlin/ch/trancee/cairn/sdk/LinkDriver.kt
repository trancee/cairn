package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.CoreException
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole

/** What the [LinkDriver] tells the app, on the driver's thread. */
sealed interface Notice {
    data class ContactsChanged(val contacts: List<ContactInfo>) : Notice

    data class ChatReceived(val contact: ULong, val msgno: UInt, val text: String) : Notice

    data class ChatSent(val contact: ULong, val msgno: UInt) : Notice

    data class ChatRejected(val contact: ULong, val reason: ChatRejection) : Notice

    /** Sealed for a later session and stored (ADR 0034 §2). */
    data class ChatQueued(val contact: ULong, val msgno: UInt) : Notice

    /** The peer's ACK covers it. */
    data class ChatDelivered(val contact: ULong, val msgno: UInt) : Notice

    /** The peer marked it read; shown only while read receipts are on. */
    data class ChatRead(val contact: ULong, val msgno: UInt) : Notice

    /** This device gave up on it: a restart lost it, or it outlived 7 days. */
    data class ChatExpired(val contact: ULong, val msgno: UInt) : Notice

    /** The peer gave up on its messages [from]..[to]; they will never arrive. */
    data class ChatsExpired(val contact: ULong, val from: UInt, val to: UInt) : Notice

    data class Fault(val kind: FaultKind) : Notice
}

enum class FaultKind {
    /** The core's crypto backend failed; that batch of actions was dropped (ADR 0022 §3). */
    CRYPTO,

    /** The core panicked; the driver closed every link and restored a new core from the last rows. */
    POISONED,

    /** Stored rows failed to open and were wiped; contacts must pair again (ADR 0035 §5). */
    STORAGE_RESET,
}

/** Debug-panel counters for one link (ADR 0023 §2); nothing secret. */
data class LinkStats(
    val link: ULong,
    val role: GattRole,
    val mtu: UShort,
    val upAtMonoMs: ULong,
    val fragmentsOut: Int,
    val bytesOut: Long,
    val fragmentsIn: Int,
    val bytesIn: Long,
)

/**
 * Connects one [Engine] to a platform [Radio] and [Timers] (ADR 0023 §2).
 *
 * Not thread-safe: the platform calls every method from one thread and posts BLE callbacks there.
 */
class LinkDriver(
    /** The core's durable rows; [SealedRowStore] in apps (ADR 0035). */
    val rows: Rows,
    private val newEngine: () -> Engine,
    private val radio: Radio,
    private val timers: Timers,
    private val clock: ClockSource,
    private val listener: (Notice) -> Unit,
) : RadioListener {
    private class Link(val role: GattRole, var mtu: UShort, val upAtMonoMs: ULong) {
        val queue = ArrayDeque<ByteArray>()
        var inFlightBytes = 0
        var unconfirmedBytes = 0
        var closing = false
        var fragmentsOut = 0
        var bytesOut = 0L
        var fragmentsIn = 0
        var bytesIn = 0L
    }

    private var engine = newEngine()
    private var nextLink = 1uL
    private val links = LinkedHashMap<ULong, Link>()
    private val activeTimers = LinkedHashSet<ULong>()

    /** Restores a fresh core and tells the app its restored contacts; call once, first. */
    fun start() {
        dispatch(restore())
        listener(Notice.ContactsChanged(contacts()))
    }

    override fun linkUp(role: GattRole, mtu: UShort, address: ByteArray): ULong {
        val now = clock.now()
        val link = nextLink++
        links[link] = Link(role, mtu, now.monoMs)
        dispatch(Event.LinkUp(link, role, mtu, address), now)
        return link
    }

    override fun mtuChanged(link: ULong, mtu: UShort) {
        links[link]?.mtu = mtu
        dispatch(Event.MtuChanged(link, mtu))
    }

    override fun beaconRead(link: ULong, beacon: ByteArray) = dispatch(Event.BeaconRead(link, beacon))

    override fun received(link: ULong, fragment: ByteArray) {
        links[link]?.let { state ->
            state.fragmentsIn++
            state.bytesIn += fragment.size
        }
        dispatch(Event.Received(link, fragment))
    }

    override fun sent(link: ULong) {
        val state = links[link] ?: return
        if (state.closing) return
        state.unconfirmedBytes -= state.inFlightBytes
        state.inFlightBytes = 0
        transmit(link, state)
    }

    override fun linkDown(link: ULong) {
        links.remove(link)
        dispatch(Event.LinkDown(link))
    }

    fun timerFired(timer: ULong) {
        if (activeTimers.remove(timer)) dispatch(Event.TimerFired(timer))
    }

    fun sendChat(contact: ULong, text: String) = dispatch(Event.SendChat(contact, text))

    /** Marks [contact]'s messages up to [msgno] read; READ goes out now or at the next session. */
    fun markRead(contact: ULong, msgno: UInt) = dispatch(Event.MarkRead(contact, msgno))

    /** Turns sending and showing read receipts on or off, for every contact. */
    fun setReadReceipts(enabled: Boolean) = dispatch(Event.SetReadReceipts(enabled))

    /** The value for the local `beacon` characteristic. */
    override fun beacon(): ByteArray = query { it.beacon(clock.now().unixS) }

    fun contacts(): List<ContactInfo> = query(Engine::contacts)

    fun links(): List<LinkStats> = links.map { (link, state) ->
        LinkStats(
            link,
            state.role,
            state.mtu,
            state.upAtMonoMs,
            state.fragmentsOut,
            state.bytesOut,
            state.fragmentsIn,
            state.bytesIn,
        )
    }

    fun close() = engine.close()

    private fun dispatch(event: Event, now: Clock = clock.now()) {
        val actions = try {
            engine.handle(now, event)
        } catch (e: CoreException.Crypto) {
            listener(Notice.Fault(FaultKind.CRYPTO))
            return
        } catch (e: CoreException.Poisoned) {
            replaceEngine()
            return
        }
        execute(actions)
    }

    /** ADR 0035 §4: a result's rows are stored before anything else in it runs. */
    private fun execute(actions: List<Action>) {
        rows.commit(actions)
        actions.forEach(::perform)
    }

    private fun restore(): Event.Restore {
        val restored = rows.restore()
        if (restored.reset) listener(Notice.Fault(FaultKind.STORAGE_RESET))
        return restored.event
    }

    private fun <T> query(read: (Engine) -> T): T = try {
        read(engine)
    } catch (e: CoreException.Poisoned) {
        replaceEngine()
        read(engine)
    }

    /** ADR 0022 §3: a poisoned core is unusable, so every link and timer it owned goes too. */
    private fun replaceEngine() {
        engine.close()
        links.keys.forEach(radio::disconnect)
        links.clear()
        activeTimers.forEach(timers::cancel)
        activeTimers.clear()
        engine = newEngine()
        // A replacement that fails its restore propagates rather than looping.
        execute(engine.handle(clock.now(), restore()))
        listener(Notice.Fault(FaultKind.POISONED))
    }

    private fun perform(action: Action) {
        when (action) {
            is Action.PersistDevice, is Action.PersistContact, is Action.PutQueued, is Action.DeleteQueued -> {}
            is Action.Send -> enqueue(action.link, action.fragment)
            is Action.Disconnect -> links[action.link]?.let { disconnect(action.link, it) }
            is Action.SetTimer -> {
                activeTimers += action.timer
                timers.schedule(action.timer, action.atMonoMs)
            }
            is Action.CancelTimer -> {
                activeTimers -= action.timer
                timers.cancel(action.timer)
            }
            is Action.ContactAdded -> listener(Notice.ContactsChanged(contacts()))
            is Action.ChatReceived -> listener(Notice.ChatReceived(action.contact, action.msgno, action.text))
            is Action.ChatSent -> listener(Notice.ChatSent(action.contact, action.msgno))
            is Action.ChatRejected -> listener(Notice.ChatRejected(action.contact, action.reason))
            is Action.ChatQueued -> listener(Notice.ChatQueued(action.contact, action.msgno))
            is Action.ChatDelivered -> listener(Notice.ChatDelivered(action.contact, action.msgno))
            is Action.ChatRead -> listener(Notice.ChatRead(action.contact, action.msgno))
            is Action.ChatExpired -> listener(Notice.ChatExpired(action.contact, action.msgno))
            is Action.ChatsExpired -> listener(Notice.ChatsExpired(action.contact, action.from, action.to))
        }
    }

    private fun enqueue(link: ULong, fragment: ByteArray) {
        val state = links[link] ?: return
        if (state.closing) return
        state.unconfirmedBytes += fragment.size
        if (state.unconfirmedBytes > MAX_QUEUED_BYTES) return disconnect(link, state)
        state.queue.addLast(fragment)
        if (state.inFlightBytes == 0) transmit(link, state)
    }

    private fun transmit(link: ULong, state: Link) {
        val fragment = state.queue.removeFirstOrNull() ?: return
        state.inFlightBytes = fragment.size
        state.fragmentsOut++
        state.bytesOut += fragment.size
        radio.send(link, fragment)
    }

    /** Stops sending; the link stays listed until the platform reports [linkDown]. */
    private fun disconnect(link: ULong, state: Link) {
        if (state.closing) return
        state.closing = true
        state.queue.clear()
        radio.disconnect(link)
    }

    companion object {
        /** Unconfirmed fragment bytes allowed per link; one 4096 B frame takes 4320 B at ATT MTU 23. */
        const val MAX_QUEUED_BYTES: Int = 32 * 1024
    }
}
