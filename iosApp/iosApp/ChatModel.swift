import CairnApp
import Combine
import Foundation

enum MessageStatus: Equatable {
    case received
    /// Sealed and stored for the contact's next session (ADR 0034 §2).
    case queued
    /// Sent on the contact's session; not yet acknowledged.
    case sent
    case delivered
    case read
    /// This device gave up on it: a restart lost it, or it outlived 7 days.
    case expired
    case rejected(ChatRejection)
    /// The core answered neither way, after a crypto fault or a core restart.
    case failed
    /// The peer's messages `from`...`to` expired before they arrived; not a message itself.
    case missed(from: UInt32, to: UInt32)
}

/// One conversation line; `msgno` numbers it within its direction, if the core assigned one.
struct Message: Equatable {
    let text: String
    var status: MessageStatus
    var msgno: UInt32?
}

/// The chat screen's state, fed by driver notices on the main queue; a port of Android's
/// `ChatModel` (ADR 0037 §6). It is kept in memory only.
final class ChatModel: ObservableObject {
    @Published var radio = RadioState.stopped
    @Published private(set) var contacts: [ContactInfo] = []
    @Published var links: [LinkStats] = []
    @Published private(set) var fault: FaultKind?
    @Published private var conversations: [UInt64: [Message]] = [:]

    private final class Pending {
        let contact: UInt64
        var status = MessageStatus.failed
        var msgno: UInt32?

        init(contact: UInt64) {
            self.contact = contact
        }
    }

    private var sending: Pending?

    func messages(_ contact: UInt64) -> [Message] {
        conversations[contact] ?? []
    }

    func onNotice(_ notice: Notice) {
        switch notice {
        case let notice as NoticeContactsChanged: contacts = notice.contacts
        case let notice as NoticeChatReceived:
            append(notice.contact, Message(text: notice.text, status: .received, msgno: notice.msgno))
        case let notice as NoticeChatSent: settle(notice.contact, .sent, notice.msgno)
        case let notice as NoticeChatQueued: settle(notice.contact, .queued, notice.msgno)
        case let notice as NoticeChatRejected: settle(notice.contact, .rejected(notice.reason), nil)
        case let notice as NoticeChatDelivered:
            update(notice.contact) { msgno, status in
                msgno == notice.msgno && status != .read ? .delivered : status
            }
        case let notice as NoticeChatRead:
            update(notice.contact) { msgno, status in
                msgno <= notice.msgno && [.queued, .sent, .delivered].contains(status) ? .read : status
            }
        case let notice as NoticeChatExpired:
            update(notice.contact) { msgno, status in msgno == notice.msgno ? .expired : status }
        case let notice as NoticeChatsExpired:
            append(notice.contact, Message(text: "", status: .missed(from: notice.from, to: notice.to), msgno: nil))
        case let notice as NoticeFault: fault = notice.kind
        default: break
        }
    }

    /// Sends `text` through `deliver`. The core answers `ChatSent`, `ChatQueued` or `ChatRejected`
    /// before `sendChat` returns, so the message is settled once `deliver` returns.
    func send(contact: UInt64, text: String, deliver: () -> Void) {
        let pending = Pending(contact: contact)
        sending = pending
        deliver()
        sending = nil
        append(contact, Message(text: text, status: pending.status, msgno: pending.msgno))
    }

    /// The highest number received from `contact`, which is what reading the conversation marks.
    func lastReceived(_ contact: UInt64) -> UInt32? {
        messages(contact).filter { $0.status == .received }.compactMap(\.msgno).max()
    }

    func dismissFault() {
        fault = nil
    }

    private func settle(_ contact: UInt64, _ status: MessageStatus, _ msgno: UInt32?) {
        guard let pending = sending, pending.contact == contact else { return }
        pending.status = status
        pending.msgno = msgno
    }

    /// Applies `next` to every message `contact` was sent; received lines keep their status.
    private func update(_ contact: UInt64, _ next: (UInt32, MessageStatus) -> MessageStatus) {
        conversations[contact] = messages(contact).map { message in
            guard let msgno = message.msgno, message.status != .received else { return message }
            var updated = message
            updated.status = next(msgno, message.status)
            return updated
        }
    }

    private func append(_ contact: UInt64, _ message: Message) {
        conversations[contact] = messages(contact) + [message]
    }
}

/// The screen's text, worded as Android's `strings.xml`.
enum Labels {
    static func contact(_ contact: ContactInfo) -> String {
        contact.name.isEmpty ? "Contact \(contact.id)" : contact.name
    }

    static func verification(_ verification: Verification) -> String {
        switch verification {
        case .verified: return "Verified"
        case .compromised: return "Key changed — not trusted"
        default: return "Unverified"
        }
    }

    static func status(_ status: MessageStatus) -> String? {
        switch status {
        case .received: return nil
        case .queued: return "Waiting for a connection"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .expired: return "Not delivered: gave up"
        case .failed: return "Not sent: internal error"
        case let .missed(from, to): return "Messages \(from)–\(to) expired before they arrived"
        case let .rejected(reason): return rejection(reason)
        }
    }

    private static func rejection(_ reason: ChatRejection) -> String {
        switch reason {
        case .tooLong: return "Not sent: message too long"
        case .exhausted: return "Not sent: message counter used up"
        case .queueFull: return "Not sent: too many undelivered messages"
        default: return "Not sent: no secure session yet"
        }
    }

    static func fault(_ kind: FaultKind) -> String {
        switch kind {
        case .crypto: return "The crypto backend failed; one step was dropped."
        case .poisoned: return "The core restarted; every link was closed."
        default: return "Secure storage was reset; contacts must pair again."
        }
    }

    static func link(_ stats: LinkStats) -> String {
        "Link \(stats.link) · \(stats.role.name) · MTU \(stats.mtu) · up at \(stats.upAtMonoMs) ms\n"
            + "out \(stats.fragmentsOut) / \(stats.bytesOut) B · in \(stats.fragmentsIn) / \(stats.bytesIn) B"
    }
}
