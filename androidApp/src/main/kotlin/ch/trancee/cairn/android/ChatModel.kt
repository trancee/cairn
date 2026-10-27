package ch.trancee.cairn.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.sdk.FaultKind
import ch.trancee.cairn.sdk.LinkStats
import ch.trancee.cairn.sdk.Notice

/** Whether the radio runs, or what the user must do first. */
enum class RadioState { STOPPED, NEEDS_PERMISSION, BLUETOOTH_OFF, RUNNING }

sealed interface MessageStatus {
    data object Received : MessageStatus

    /** Sealed and stored for the contact's next session (ADR 0034 §2). */
    data object Queued : MessageStatus

    /** Sent on the contact's session; not yet acknowledged. */
    data object Sent : MessageStatus

    /** The peer acknowledged it. */
    data object Delivered : MessageStatus

    /** The peer read it; shown only while read receipts are on. */
    data object Read : MessageStatus

    /** This device gave up on it: a restart lost it, or it outlived 7 days. */
    data object Expired : MessageStatus

    data class Rejected(val reason: ChatRejection) : MessageStatus

    /** The core answered neither way, after a crypto fault or a core restart. */
    data object Failed : MessageStatus

    /** The peer's messages [from]..[to] expired before they arrived; not a message itself. */
    data class Missed(val from: UInt, val to: UInt) : MessageStatus
}

/** One conversation line; [msgno] numbers it within its direction, if the core assigned one. */
data class Message(val text: String, val status: MessageStatus, val msgno: UInt? = null)

/** The chat screen's state, fed by [Notice]s on the main thread. It is kept in memory only. */
class ChatModel {
    var radio by mutableStateOf(RadioState.STOPPED)

    var contacts by mutableStateOf(emptyList<ContactInfo>())
        private set

    var links by mutableStateOf(emptyList<LinkStats>())

    var fault by mutableStateOf<FaultKind?>(null)
        private set

    /** The open conversation; it lives here so it survives activity recreation. */
    var open by mutableStateOf<ContactInfo?>(null)

    private val conversations = mutableStateMapOf<ULong, List<Message>>()

    private class Pending(val contact: ULong) {
        var status: MessageStatus = MessageStatus.Failed
        var msgno: UInt? = null
    }

    private var sending: Pending? = null

    fun messages(contact: ULong): List<Message> = conversations[contact].orEmpty()

    fun onNotice(notice: Notice) {
        when (notice) {
            is Notice.ContactsChanged -> contacts = notice.contacts
            is Notice.ChatReceived ->
                append(notice.contact, Message(notice.text, MessageStatus.Received, notice.msgno))
            is Notice.ChatSent -> settle(notice.contact, MessageStatus.Sent, notice.msgno)
            is Notice.ChatQueued -> settle(notice.contact, MessageStatus.Queued, notice.msgno)
            is Notice.ChatRejected -> settle(notice.contact, MessageStatus.Rejected(notice.reason), null)
            is Notice.ChatDelivered -> update(notice.contact) { msgno, status ->
                if (msgno == notice.msgno && status != MessageStatus.Read) MessageStatus.Delivered else status
            }
            is Notice.ChatRead -> update(notice.contact) { msgno, status ->
                if (msgno <= notice.msgno && status in UNREAD) MessageStatus.Read else status
            }
            is Notice.ChatExpired -> update(notice.contact) { msgno, status ->
                if (msgno == notice.msgno) MessageStatus.Expired else status
            }
            is Notice.ChatsExpired -> append(notice.contact, Message("", MessageStatus.Missed(notice.from, notice.to)))
            is Notice.Fault -> fault = notice.kind
        }
    }

    /**
     * Sends [text] through [deliver]. The core answers `ChatSent`, `ChatQueued` or `ChatRejected`
     * before `sendChat` returns, so the message is settled once [deliver] returns.
     */
    fun send(contact: ULong, text: String, deliver: () -> Unit) {
        val pending = Pending(contact)
        sending = pending
        deliver()
        sending = null
        append(contact, Message(text, pending.status, pending.msgno))
    }

    /** The highest number received from [contact], which is what reading the conversation marks. */
    fun lastReceived(contact: ULong): UInt? =
        messages(contact).filter { it.status == MessageStatus.Received }.mapNotNull { it.msgno }.maxOrNull()

    fun dismissFault() {
        fault = null
    }

    private fun settle(contact: ULong, status: MessageStatus, msgno: UInt?) {
        val pending = sending?.takeIf { it.contact == contact } ?: return
        pending.status = status
        pending.msgno = msgno
    }

    /** Applies [next] to every message [contact] was sent; received lines keep their status. */
    private inline fun update(contact: ULong, next: (UInt, MessageStatus) -> MessageStatus) {
        conversations[contact] = messages(contact).map { message ->
            val msgno = message.msgno
            if (msgno == null || message.status == MessageStatus.Received) message
            else message.copy(status = next(msgno, message.status))
        }
    }

    private fun append(contact: ULong, message: Message) {
        conversations[contact] = messages(contact) + message
    }
}

/** The states a read receipt moves to [MessageStatus.Read]. */
private val UNREAD = setOf(MessageStatus.Queued, MessageStatus.Sent, MessageStatus.Delivered)
