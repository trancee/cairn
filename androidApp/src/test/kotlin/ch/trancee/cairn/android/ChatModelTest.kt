package ch.trancee.cairn.android

import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.sdk.FaultKind
import ch.trancee.cairn.sdk.Notice
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

class ChatModelTest {
    private val model = ChatModel()

    @Test
    fun contactsChangedReplacesTheContactList() {
        val contacts = listOf(AppHarness.contact(1u), AppHarness.contact(2u, "Ada"))

        model.onNotice(Notice.ContactsChanged(contacts))

        assertEquals(contacts, model.contacts)
    }

    @Test
    fun aReceivedChatJoinsOnlyItsContactsConversation() {
        model.onNotice(Notice.ChatReceived(1u, 1u, "hi"))

        assertEquals(listOf(Message("hi", MessageStatus.Received, 1u)), model.messages(1u))
        assertEquals(emptyList(), model.messages(2u))
    }

    @Test
    fun aSendIsSentWhenTheCoreSealsIt() {
        model.send(1u, "hello") { model.onNotice(Notice.ChatSent(1u, 1u)) }

        assertEquals(listOf(Message("hello", MessageStatus.Sent, 1u)), model.messages(1u))
    }

    @Test
    fun aSendWithoutASessionIsQueued() {
        model.send(1u, "later") { model.onNotice(Notice.ChatQueued(1u, 4u)) }

        assertEquals(listOf(Message("later", MessageStatus.Queued, 4u)), model.messages(1u))
    }

    @Test
    fun receiptsMoveOnlyTheirOwnContactsMessages() {
        for (msgno in 1u..3u) model.send(1u, "m$msgno") { model.onNotice(Notice.ChatSent(1u, msgno)) }
        model.send(2u, "other") { model.onNotice(Notice.ChatSent(2u, 1u)) }

        model.onNotice(Notice.ChatDelivered(1u, 1u))
        model.onNotice(Notice.ChatDelivered(1u, 2u))
        model.onNotice(Notice.ChatRead(1u, 1u))
        model.onNotice(Notice.ChatDelivered(1u, 1u))
        model.onNotice(Notice.ChatExpired(1u, 3u))

        assertEquals(
            listOf(MessageStatus.Read, MessageStatus.Delivered, MessageStatus.Expired),
            model.messages(1u).map { it.status },
        )
        assertEquals(listOf(MessageStatus.Sent), model.messages(2u).map { it.status })
    }

    @Test
    fun aReadReceiptCoversEverySentMessageUpToIt() {
        model.onNotice(Notice.ChatReceived(1u, 1u, "hi"))
        model.send(1u, "a") { model.onNotice(Notice.ChatQueued(1u, 1u)) }
        model.send(1u, "b") { model.onNotice(Notice.ChatSent(1u, 2u)) }
        model.send(1u, "c") { model.onNotice(Notice.ChatSent(1u, 3u)) }
        model.send(1u, "d") { model.onNotice(Notice.ChatRejected(1u, ChatRejection.QUEUE_FULL)) }
        model.onNotice(Notice.ChatExpired(1u, 2u))

        model.onNotice(Notice.ChatRead(1u, 2u))

        assertEquals(
            listOf(
                MessageStatus.Received,
                MessageStatus.Read,
                MessageStatus.Expired,
                MessageStatus.Sent,
                MessageStatus.Rejected(ChatRejection.QUEUE_FULL),
            ),
            model.messages(1u).map { it.status },
        )
    }

    @Test
    fun aPeersExpiredRangeIsShownInTheConversation() {
        model.onNotice(Notice.ChatsExpired(1u, 2u, 5u))

        assertEquals(listOf(Message("", MessageStatus.Missed(2u, 5u))), model.messages(1u))
    }

    @Test
    fun theLastReceivedNumberIsWhatToMarkRead() {
        model.onNotice(Notice.ChatReceived(1u, 1u, "a"))
        model.onNotice(Notice.ChatReceived(1u, 3u, "c"))
        model.send(1u, "b") { model.onNotice(Notice.ChatSent(1u, 9u)) }

        assertEquals(3u, model.lastReceived(1u))
        assertNull(model.lastReceived(2u))
    }

    @Test
    fun aSendKeepsTheCoresRejectionReason() {
        model.send(1u, "hello") { model.onNotice(Notice.ChatRejected(1u, ChatRejection.NO_SESSION)) }

        assertEquals(
            listOf(Message("hello", MessageStatus.Rejected(ChatRejection.NO_SESSION))),
            model.messages(1u),
        )
    }

    @Test
    fun aSendTheCoreNeverAnsweredFails() {
        model.send(1u, "hello") {}

        assertEquals(listOf(Message("hello", MessageStatus.Failed)), model.messages(1u))
    }

    @Test
    fun answersForAnotherContactDoNotSettleASend() {
        model.send(1u, "hello") {
            model.onNotice(Notice.ChatSent(2u, 1u))
            model.onNotice(Notice.ChatRejected(2u, ChatRejection.TOO_LONG))
        }

        assertEquals(listOf(Message("hello", MessageStatus.Failed)), model.messages(1u))
        assertEquals(emptyList(), model.messages(2u))
    }

    @Test
    fun answersOutsideASendAreIgnored() {
        model.onNotice(Notice.ChatSent(1u, 1u))
        model.onNotice(Notice.ChatRejected(1u, ChatRejection.EXHAUSTED))

        assertEquals(emptyList(), model.messages(1u))
    }

    @Test
    fun aFaultIsShownUntilDismissed() {
        model.onNotice(Notice.Fault(FaultKind.CRYPTO))
        assertEquals(FaultKind.CRYPTO, model.fault)

        model.dismissFault()

        assertNull(model.fault)
    }
}
