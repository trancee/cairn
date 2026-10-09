# cairn

Post-quantum secure peer-to-peer messaging between nearby devices over Bluetooth Low Energy.

The name is a cairn: a stack of stones marking a path, each placed on the last, like the one-way ratchet. See [ADR 0011](docs/adr/0011-project-name.md).

## Language

**Peer**:
A device running `cairn` that takes part in a pairwise relationship with another.
_Avoid_: Node, client, partner

**Contact**:
A peer that this device has paired with and holds shared state for.
_Avoid_: Bond, paired device, friend

**Pairing**:
The one-time act by which two peers become contacts and establish post-quantum shared secrets, performed by `cairn` itself on top of an ordinary, unencrypted BLE connection. It is **not** Bluetooth pairing: the operating system's Bluetooth pairing and bonding are never used, no Bluetooth keys are created, and nothing appears in the system's Bluetooth settings.
_Avoid_: Introduction, enrollment, handshake

**Bluetooth pairing**:
The operating system's own link-layer key exchange (Secure Simple Pairing / LE Secure Connections) and the resulting **bond**. Out of scope for `cairn`; always say "Bluetooth pairing", never just "pairing", when this is meant.
_Avoid_: Pairing (unqualified), bonding when meaning `cairn` pairing

**Pairing role**:
Which side of a contact relationship a device is (A or B), fixed once at pairing and used wherever the two sides must act asymmetrically.
_Avoid_: Initiator, master, primary

**Verification**:
Confirming in person that no one sits between the two peers, by QR scan or short authentication string, either during pairing or later for an unverified contact. A contact without it is **unverified**.
_Avoid_: Authentication, trust

**Resume**:
The short exchange two contacts perform on each connection to derive fresh session keys from their shared state.
_Avoid_: Reconnect, handshake, login

**Session**:
The protected channel between two contacts, from one resume until disconnection.
_Avoid_: Connection, link

**Resume index**:
The count of resumes completed between two contacts since pairing; each resume advances it by one.
_Avoid_: Epoch, session number

**Epoch**:
A period of the post-quantum ratchet bounded by two consecutive post-quantum key refreshes.
_Avoid_: Round, generation

**Beacon**:
A short, rotating value by which any of a peer's contacts recognises it nearby; strangers can't link it over time.
_Avoid_: Advertisement, ID, tag

**Doorbell**:
A tiny connectionless signal telling a contact "I have something for you".
_Avoid_: Ping, notification, wake-up

**Queued message**:
A chat message sealed at send time that waits for the next session with its contact to be delivered.
_Avoid_: Offline message, pending message, outbox item

**Delivery**:
The moment a contact's device acknowledges receiving a message. A message that expires first is **not delivered**.
_Avoid_: Sent, received

**Read receipt**:
A notice that the contact has displayed a delivered message.
_Avoid_: Seen, read ack

**KCI profile**:
An opt-in per-contact mode that keeps a peer from being impersonated to a device whose long-term state was stolen.
_Avoid_: Strict mode, paranoid mode

**Contact removal**:
Deleting a contact so that its keys are destroyed and its stored conversation becomes permanently unreadable.
_Avoid_: Unpairing, blocking

**Compromised contact**:
A contact whose later verification failed, meaning its pairing was intercepted. Nothing more can be sent to it until it is removed and paired again.
_Avoid_: Untrusted, blocked

**Re-pairing**:
Pairing again with someone who is already a contact, after a reinstall, a move to a new device, or a storage reset.
_Avoid_: Recovery, restore
