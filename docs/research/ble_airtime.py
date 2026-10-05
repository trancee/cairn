"""Approximate BLE link-layer airtime for handshake payload sizes.

Model: encrypted LL data PDUs (MIC 4 B), DLE payload <= 251 B, one empty ACK
PDU per data PDU, T_IFS 150 us, L2CAP header 4 B per 247-byte SDU segment.
Ignores connection-event scheduling, retransmissions, and controller limits.
"""
import math

LINK_LAYER_MAX_PAYLOAD = 251
LEGACY_LINK_LAYER_PAYLOAD = 27
INTER_FRAME_SPACE_US = 150


def pdu_count(payload_bytes: int, link_layer_payload: int) -> int:
    return math.ceil(payload_bytes / link_layer_payload)


def airtime_microseconds(payload_bytes: int, phy_mbps: int) -> float:
    preamble = phy_mbps
    overhead = preamble + 4 + 2 + 4 + 3  # access address, header, MIC, CRC
    empty_ack = preamble + 4 + 2 + 3
    total = 0.0
    remaining = payload_bytes
    while remaining > 0:
        chunk = min(LINK_LAYER_MAX_PAYLOAD, remaining)
        remaining -= chunk
        total += (overhead + chunk) * 8 / phy_mbps + INTER_FRAME_SPACE_US
        total += empty_ack * 8 / phy_mbps + INTER_FRAME_SPACE_US
    return total


DESIGNS = {
    "PROMPT.md CSIDH-512 (insecure level)": 65 + 81,
    "CSIDH ~4096-bit class (est. 512 B keys)": 513 + 529,
    "ML-KEM-512 ephemeral per session": 800 + 768 + 2 * 20,
    "X-Wing pairing (ML-KEM-768 + X25519)": 1216 + 1120 + 2 * 20,
    "Proposed session resume (S1 + S2)": 57 + 49,
    "Proposed amortized ML-KEM-768 rekey": 1184 + 1088,
}

if __name__ == "__main__":
    for name, size in DESIGNS.items():
        on_air = size + 4 * math.ceil(size / 247)
        print(
            f"{name:42s} {size:6d} B  "
            f"PDUs@251={pdu_count(on_air, LINK_LAYER_MAX_PAYLOAD):3d}  "
            f"PDUs@27={pdu_count(on_air, LEGACY_LINK_LAYER_PAYLOAD):3d}  "
            f"2M={airtime_microseconds(on_air, 2) / 1000:6.2f} ms  "
            f"1M={airtime_microseconds(on_air, 1) / 1000:6.2f} ms"
        )
