import CairnApp
import XCTest
@testable import CairnIos

final class ChatModelTests: XCTestCase {
    private let model = ChatModel()

    private func contact(_ id: UInt64, _ name: String = "", _ verification: Verification = .unverified) -> ContactInfo {
        ContactInfo(id: id, name: name, verification: verification)
    }

    private func sent(_ text: String, to contact: UInt64 = 1, answer: Notice?) {
        model.send(contact: contact, text: text) {
            if let answer { model.onNotice(answer) }
        }
    }

    func testContactsChangedReplacesTheList() {
        model.onNotice(NoticeContactsChanged(contacts: [contact(1), contact(2)]))

        XCTAssertEqual(model.contacts.map(\.id), [1, 2])
    }

    func testReceivedMessagesAppendInOrder() {
        model.onNotice(NoticeChatReceived(contact: 1, msgno: 1, text: "hi"))
        model.onNotice(NoticeChatReceived(contact: 1, msgno: 2, text: "there"))

        XCTAssertEqual(model.messages(1), [
            Message(text: "hi", status: .received, msgno: 1),
            Message(text: "there", status: .received, msgno: 2),
        ])
        XCTAssertEqual(model.messages(2), [])
    }

    func testSendSettlesWithTheCoreAnswer() {
        sent("a", answer: NoticeChatSent(contact: 1, msgno: 4))
        sent("b", answer: NoticeChatQueued(contact: 1, msgno: 5))
        sent("c", answer: NoticeChatRejected(contact: 1, reason: .tooLong))
        sent("d", answer: nil)
        sent("e", answer: NoticeChatSent(contact: 2, msgno: 1))

        XCTAssertEqual(model.messages(1).map(\.status), [.sent, .queued, .rejected(.tooLong), .failed, .failed])
        XCTAssertEqual(model.messages(1).map(\.msgno), [4, 5, nil, nil, nil])
    }

    func testAnswersOutsideASendAreIgnored() {
        model.onNotice(NoticeChatSent(contact: 1, msgno: 4))

        XCTAssertEqual(model.messages(1), [])
    }

    func testDeliveryReadAndExpiryUpdateSentMessages() {
        model.onNotice(NoticeChatReceived(contact: 1, msgno: 1, text: "in"))
        sent("a", answer: NoticeChatSent(contact: 1, msgno: 1))
        sent("b", answer: NoticeChatSent(contact: 1, msgno: 2))
        sent("c", answer: NoticeChatQueued(contact: 1, msgno: 3))
        sent("d", answer: NoticeChatSent(contact: 1, msgno: 4))
        sent("e", answer: NoticeChatRejected(contact: 1, reason: .noSession))

        model.onNotice(NoticeChatDelivered(contact: 1, msgno: 2))
        model.onNotice(NoticeChatRead(contact: 1, msgno: 2))
        model.onNotice(NoticeChatDelivered(contact: 1, msgno: 2))
        model.onNotice(NoticeChatExpired(contact: 1, msgno: 4))
        model.onNotice(NoticeChatRead(contact: 1, msgno: 4))

        XCTAssertEqual(
            model.messages(1).map(\.status),
            [.received, .read, .read, .read, .expired, .rejected(.noSession)]
        )
    }

    func testExpiredRangeAddsAMissedLine() {
        model.onNotice(NoticeChatsExpired(contact: 1, from: 3, to: 5))

        XCTAssertEqual(model.messages(1), [Message(text: "", status: .missed(from: 3, to: 5), msgno: nil)])
    }

    func testFaultShowsUntilDismissed() {
        model.onNotice(NoticeFault(kind: .poisoned))
        XCTAssertEqual(model.fault, .poisoned)

        model.dismissFault()

        XCTAssertNil(model.fault)
    }

    func testLastReceivedIsTheHighestReceivedNumber() {
        XCTAssertNil(model.lastReceived(1))
        model.onNotice(NoticeChatReceived(contact: 1, msgno: 3, text: "a"))
        model.onNotice(NoticeChatReceived(contact: 1, msgno: 2, text: "b"))
        sent("c", answer: NoticeChatSent(contact: 1, msgno: 9))

        XCTAssertEqual(model.lastReceived(1), 3)
    }

    func testLabelsMatchTheAndroidStrings() {
        XCTAssertEqual(Labels.contact(contact(7)), "Contact 7")
        XCTAssertEqual(Labels.contact(contact(7, "Ada")), "Ada")
        XCTAssertEqual(Labels.verification(.unverified), "Unverified")
        XCTAssertEqual(Labels.verification(.verified), "Verified")
        XCTAssertEqual(Labels.verification(.compromised), "Key changed — not trusted")
        XCTAssertNil(Labels.status(.received))
        XCTAssertEqual(Labels.status(.queued), "Waiting for a connection")
        XCTAssertEqual(Labels.status(.sent), "Sent")
        XCTAssertEqual(Labels.status(.delivered), "Delivered")
        XCTAssertEqual(Labels.status(.read), "Read")
        XCTAssertEqual(Labels.status(.expired), "Not delivered: gave up")
        XCTAssertEqual(Labels.status(.failed), "Not sent: internal error")
        XCTAssertEqual(Labels.status(.missed(from: 3, to: 5)), "Messages 3–5 expired before they arrived")
        XCTAssertEqual(Labels.status(.rejected(.noSession)), "Not sent: no secure session yet")
        XCTAssertEqual(Labels.status(.rejected(.tooLong)), "Not sent: message too long")
        XCTAssertEqual(Labels.status(.rejected(.exhausted)), "Not sent: message counter used up")
        XCTAssertEqual(Labels.status(.rejected(.queueFull)), "Not sent: too many undelivered messages")
        XCTAssertEqual(Labels.fault(.crypto), "The crypto backend failed; one step was dropped.")
        XCTAssertEqual(Labels.fault(.poisoned), "The core restarted; every link was closed.")
        XCTAssertEqual(Labels.fault(.storageReset), "Secure storage was reset; contacts must pair again.")
        let stats = LinkStats(
            link: 2, role: .peripheral, mtu: 185, upAtMonoMs: 1_500,
            fragmentsOut: 3, bytesOut: 300, fragmentsIn: 4, bytesIn: 400
        )
        XCTAssertEqual(Labels.link(stats), "Link 2 · PERIPHERAL · MTU 185 · up at 1500 ms\nout 3 / 300 B · in 4 / 400 B")
    }
}
