import CairnApp
import SwiftUI
import UIKit

/// The S3 chat screen, a port of Android's `CairnScreen` (ADR 0037 §6): a gate while the radio
/// can't run, else the contact list, one conversation, the fault banner and the links panel.
struct ContentView: View {
    let session: Session
    @ObservedObject var model: ChatModel
    @State private var showLinks = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let fault = model.fault {
                    HStack {
                        Text(Labels.fault(fault)).font(.footnote)
                        Spacer()
                        Button("Dismiss") { model.dismissFault() }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                }
                switch model.radio {
                case .needsPermission:
                    Gate(
                        title: "Nearby devices",
                        detail: "Cairn finds and talks to nearby phones over Bluetooth. It never uses your location.",
                        action: "App settings",
                        perform: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                    )
                case .bluetoothOff:
                    Gate(title: "Bluetooth is off", detail: "Turn on Bluetooth to reach nearby phones.", action: nil, perform: {})
                case .stopped, .running:
                    contacts
                }
                if showLinks {
                    LinksPanel(links: model.links)
                }
            }
            .navigationTitle("Cairn")
            .toolbar {
                Button(showLinks ? "Hide links" : "Show links") { showLinks.toggle() }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var contacts: some View {
        if model.contacts.isEmpty {
            Spacer()
            Text("No contacts yet. Open Cairn on a nearby phone and keep both screens on to pair.")
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        } else {
            List(model.contacts, id: \.id) { contact in
                NavigationLink(destination: ConversationView(session: session, model: model, contact: contact)) {
                    VStack(alignment: .leading) {
                        Text(Labels.contact(contact))
                        Text(Labels.verification(contact.verification)).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct Gate: View {
    let title: String
    let detail: String
    let action: String?
    let perform: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title).font(.headline)
            Text(detail).multilineTextAlignment(.center)
            if let action {
                Button(action, action: perform)
            }
            Spacer()
        }
        .padding()
    }
}

private struct LinksPanel: View {
    let links: [LinkStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if links.isEmpty {
                Text("No links")
            }
            ForEach(links, id: \.link) { Text(Labels.link($0)) }
        }
        .font(.caption.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.15))
    }
}

private struct ConversationView: View {
    let session: Session
    @ObservedObject var model: ChatModel
    let contact: ContactInfo
    @State private var draft = ""

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(model.messages(contact.id).enumerated()), id: \.offset) { index, message in
                        Bubble(message: message).id(index)
                    }
                }
                .onChange(of: model.messages(contact.id).count) { count in
                    session.read(contact: contact.id)
                    if count > 0 { proxy.scrollTo(count - 1) }
                }
            }
            HStack {
                TextField("Message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    session.send(contact: contact.id, text: draft)
                    draft = ""
                }
                .disabled(draft.isEmpty)
            }
            .padding()
        }
        .navigationTitle(Labels.contact(contact))
        .onAppear { session.read(contact: contact.id) }
    }
}

private struct Bubble: View {
    let message: Message

    var body: some View {
        let outgoing = message.status != .received
        VStack(alignment: outgoing ? .trailing : .leading) {
            if case .missed = message.status {} else {
                Text(message.text)
            }
            if let status = Labels.status(message.status) {
                Text(status).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
    }
}
