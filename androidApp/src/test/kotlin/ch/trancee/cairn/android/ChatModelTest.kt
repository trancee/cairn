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

        assertEquals(listOf(Message("hi", MessageStatus.Received)), model.messages(1u))
        assertEquals(emptyList(), model.messages(2u))
    }

    @Test
    fun aSendIsSentWhenTheCoreSealsIt() {
        model.send(1u, "hello") { model.onNotice(Notice.ChatSent(1u, 1u)) }

        assertEquals(listOf(Message("hello", MessageStatus.Sent)), model.messages(1u))
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
