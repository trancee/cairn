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

    /** Sealed and queued on the contact's session; S2 has no delivery receipt. */
    data object Sent : MessageStatus

    data class Rejected(val reason: ChatRejection) : MessageStatus

    /** The core answered neither way, after a crypto fault or a core restart. */
    data object Failed : MessageStatus
}

data class Message(val text: String, val status: MessageStatus)

/** The chat screen's state, fed by [Notice]s on the main thread. S2 keeps it in memory only. */
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
    }

    private var sending: Pending? = null

    fun messages(contact: ULong): List<Message> = conversations[contact].orEmpty()

    fun onNotice(notice: Notice) {
        when (notice) {
            is Notice.ContactsChanged -> contacts = notice.contacts
            is Notice.ChatReceived -> append(notice.contact, Message(notice.text, MessageStatus.Received))
            is Notice.ChatSent -> settle(notice.contact, MessageStatus.Sent)
            is Notice.ChatRejected -> settle(notice.contact, MessageStatus.Rejected(notice.reason))
            is Notice.Fault -> fault = notice.kind
        }
    }

    /**
     * Sends [text] through [deliver]. The core answers `ChatSent` or `ChatRejected` before
     * `sendChat` returns, so the message is settled once [deliver] returns.
     */
    fun send(contact: ULong, text: String, deliver: () -> Unit) {
        val pending = Pending(contact)
        sending = pending
        deliver()
        sending = null
        append(contact, Message(text, pending.status))
    }

    fun dismissFault() {
        fault = null
    }

    private fun settle(contact: ULong, status: MessageStatus) {
        val pending = sending?.takeIf { it.contact == contact } ?: return
        pending.status = status
    }

    private fun append(contact: ULong, message: Message) {
        conversations[contact] = messages(contact) + message
    }
}
