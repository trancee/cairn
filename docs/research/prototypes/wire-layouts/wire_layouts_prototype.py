"""PROTOTYPE, throwaway: pqcble-r1 wire layouts and byte counts.

Question: what does every pqcble-r1 message cost on air, and do the proposed
layouts fit BLE's limits (legacy advertising, 2560 B pre-auth, ATT MTU)?

Run: python3 docs/research/prototypes/wire-layouts/wire_layouts_prototype.py
Spec draft: docs/research/2026-10-05-wire-format-draft.md
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from ble_airtime import airtime_microseconds  # noqa: E402

# Primitive sizes (ADR 0001)
XWING_EK, XWING_CT = 1216, 1120
MLKEM_EK, MLKEM_CT = 1184, 1088
X25519 = 32
TAG, DOOR_TAG = 16, 8
PSEUDONYM, BEACON = 8, 8
MAC, CONFIRM = 16, 16
NONCE = 16
HASH = 32  # SHA-384 truncated to 256 bits for commitments / ek hashes

ATT_HDR, L2CAP_HDR = 3, 4
PLAINTEXT_BUCKETS = (32, 64, 128, 256, 512, 1024, 2048, 4096 - 1 - TAG)


def leb128(n: int) -> int:
    return max(1, math.ceil(n.bit_length() / 7))


def record(body: int) -> int:
    return 1 + leb128(body) + body  # type | len | body


def pad(plaintext: int, policy: str) -> int:
    if policy == "none":
        return plaintext
    if policy == "16":
        return math.ceil(plaintext / 16) * 16
    return next(b for b in PLAINTEXT_BUCKETS if b >= plaintext)


def data_frame(records: list[int], policy: str) -> int:
    return 1 + pad(sum(records), policy) + TAG  # hdr | AES-GCM(ct) | tag


def chat(text: int, msgno: int = 300) -> int:
    return record(leb128(msgno) + text)


def sealed(text: int, msgno: int = 300) -> int:
    return 1 + leb128(msgno) + text + TAG  # gen | msgno | ct | tag


def ack(msgno: int = 300) -> int:
    return record(leb128(msgno))


def fragments(frame: int, att_mtu: int) -> int:
    value = att_mtu - ATT_HDR
    return 1 if frame <= value else math.ceil((frame - 1) / (value - 1))


def on_air(frame: int, att_mtu: int) -> tuple[int, int, float]:
    """(fragments, ATT bytes incl. repeated header, 2M airtime ms)."""
    n = fragments(frame, att_mtu)
    att_bytes = frame + (n - 1)
    per_value = att_mtu - ATT_HDR
    us, left = 0.0, att_bytes
    while left > 0:
        chunk = min(per_value, left)
        left -= chunk
        us += airtime_microseconds(chunk + ATT_HDR + L2CAP_HDR, 2)
    return n, att_bytes, us / 1000


MESSAGES = {
    # Pairing (once per contact)
    "QR payload (out of band)": 1 + HASH + NONCE,
    "P1 A→B ver|mode|commit|ek": 1 + 1 + 1 + HASH + XWING_EK,
    "P2 B→A ct|nB": 1 + XWING_CT + NONCE,
    "P3 A→B nA|confirm|card(64)": 1 + NONCE + CONFIRM + 64 + TAG,
    "P4 B→A confirm|card(64)": 1 + CONFIRM + 64 + TAG,
    "P3 +KCI static ek": 1 + NONCE + CONFIRM + 64 + MLKEM_EK + TAG,
    # Resume (every connection)
    "S1 I→R pseudo|eI|mac": 1 + PSEUDONYM + X25519 + MAC,
    "S2 R→I eR|confirm": 1 + X25519 + CONFIRM,
    "S1 KCI (+ct to R static)": 1 + PSEUDONYM + X25519 + MLKEM_CT + MAC,
    "S2 KCI (+ct to I static)": 1 + X25519 + MLKEM_CT + CONFIRM,
    # Data (per message), no padding / 16 / buckets
    **{
        f"chat {n:3d} B real-time [{p}]": data_frame([chat(n)], p)
        for n in (2, 30, 200)
        for p in ("none", "16", "buckets")
    },
    "chat  30 B queued, delivered [buckets]": data_frame([record(sealed(30))], "buckets"),
    "ack only [none]": data_frame([ack()], "none"),
    "ack + read receipt [none]": data_frame([ack(), ack()], "none"),
    # PQ ratchet epoch (ek one way, ct back), as dedicated 4 KiB frames
    "KEM epoch ek (1184) carried": data_frame([record(1 + 2 + MLKEM_EK)], "none"),
    "KEM epoch ct (1088) carried": data_frame([record(1 + 2 + MLKEM_CT)], "none"),
}

ADV = {
    "legacy adv: flags + svc-data(128-bit UUID) + beacon": 3 + (2 + 16 + BEACON),
    "legacy adv: doorbell tag replaces beacon slot": 3 + (2 + 16 + BEACON),
    "legacy adv: + doorbell as 2nd 8 B PRF tag": 3 + (2 + 16 + BEACON + BEACON),
    "legacy adv: old doorbell beacon|ctr|AEAD(flags)|tag": 3 + (2 + 16 + BEACON + 4 + 1 + DOOR_TAG),
}

if __name__ == "__main__":
    mtus = (23, 185, 247, 517)
    head = f"{'message':42s} {'bytes':>6s} " + " ".join(f"{'frags@' + str(m):>10s}" for m in mtus)
    print(head + f" {'2M ms@247':>10s}")
    for name, size in MESSAGES.items():
        cols = " ".join(f"{on_air(size, m)[0]:>10d}" for m in mtus)
        print(f"{name:42s} {size:6d} {cols} {on_air(size, 247)[2]:10.2f}")
    print()
    for name, size in ADV.items():
        verdict = "fits" if size <= 31 else "DOES NOT FIT"
        print(f"{name:55s} {size:3d} / 31 B  {verdict}")
    s = MESSAGES["S1 I→R pseudo|eI|mac"] + MESSAGES["S2 R→I eR|confirm"]
    print(f"\nResume round trip: {s} B; pre-auth limit 2560 B: max pairing frame "
          f"{max(v for k, v in MESSAGES.items() if k.startswith('P'))} B")
