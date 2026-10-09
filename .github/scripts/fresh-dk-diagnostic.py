"""Bounded crash reproduction, not a replacement for certificate replay gates."""

import hashlib
import os
from pathlib import Path
import platform
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "docs/spec/models"))
from replay import ReplayError, check_result, compare_replay, run, select_certificate


def main() -> int:
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    source = output / "assembled.spthy"
    selected = output / "fresh-dk.spthy"
    canonical = output / "roundtrip.spthy"
    base = ["tamarin-prover", "--quit-on-warning", "--derivcheck-timeout=60"]
    uses = ("kem_ciphertext_origin",)
    target = "fresh_dk_origin"
    metadata = (
        f"Platform: {platform.platform()}\n"
        f"Python: {platform.python_version()}\n"
        f"CPUs: {os.cpu_count()}\n"
        f"GHCRTS: {os.environ.get('GHCRTS', '(unset)')}\n"
        + run(["tamarin-prover", "--version"], 30)
        + run(["tamarin-prover", "+RTS", "--info"], 30)
    )
    (output / "runtime.txt").write_text(metadata)
    print(metadata, flush=True)
    run(
        base + [str(ROOT / "docs/spec/models/ratchet.spthy"),
                "--defines=DISCLOSURE_SOURCES", "--output-module=msr",
                f"--output={source}"],
        120,
    )
    text = source.read_text()
    candidate, retained = select_certificate(text, target, "all-traces", uses)
    selected.write_text(candidate)
    run(
        base + [str(selected), "--output-module=msr", f"--output={canonical}"],
        120,
    )
    compare_replay(text, canonical.read_text(), target, "all-traces", uses)
    for name, path, expected in [
        ("Source", source,
         "c393e8cea8a93bef1112214dae2c22e5f750de4991cf05372ce525cf740e1b2b"),
        ("Replay", canonical,
         "9b6a25a568a9b3024d43263649009c2df4263d1625d7a56dccbfded489f3535d"),
    ]:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"{name} SHA-256: {digest}", flush=True)
        if digest != expected:
            raise ReplayError(f"{name}: does not match the failed CI input")

    failures = 0
    crashes = 0
    results = []
    for attempt in range(1, 21):
        started = time.monotonic()
        try:
            log = run(base + [str(selected)], 180)
            check_result(log, retained)
        except ReplayError as error:
            log = str(error)
            failures += 1
            exact_crash = "command failed (1):" in log and "tamarin-prover: <<loop>>" in log
            crashes += int(exact_crash)
            verdict = "EXACT LOOP CRASH" if exact_crash else "OTHER FAILURE"
        else:
            verdict = "ALL FIVE CERTIFICATES VERIFIED"
        (output / f"replay-{attempt:02}.txt").write_text(log)
        result = f"{attempt}: {verdict}; elapsed={time.monotonic() - started:.2f}s"
        results.append(result)
        (output / "summary.txt").write_text("\n".join(results) + "\n")
        print(result, flush=True)
    summary = f"Failures={failures}/20; exact loop crashes={crashes}/20\n"
    with (output / "summary.txt").open("a") as stream:
        stream.write(summary)
    print(summary, flush=True)
    return int(failures != 0)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ReplayError) as error:
        print(f"DIAGNOSTIC SETUP FAILED: {error}", file=sys.stderr)
        sys.exit(1)
