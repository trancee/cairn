# Reference app scope

Type: grilling
Status: resolved
Blocked by:

## Question

What does the reference app have to do to count as 'working'? Candidate: contacts via pairing (QR/SAS/TOFU), 1:1 chat, queued/unread messages, verification status, and a debug panel showing bytes, PDUs, airtime and ratchet epoch. What is explicitly excluded (attachments, notifications, multi-device, backups)?

## Answer

**Minimal chat + debug panel** (user, 2026-10-05):
- contacts via pairing (QR / SAS / TOFU) with verified/unverified badge;
- 1:1 text chat with unread/queued state;
- debug panel: bytes, PDUs, airtime, ratchet epoch, RSSI.

Excluded: attachments, push notifications, multi-device, backups, group chat.
