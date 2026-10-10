#!/usr/bin/env python3
"""Check effective Linux proof-unit resource limits."""

import argparse
import json
import resource
import sys
from pathlib import Path


def observe() -> dict:
    membership = Path("/proc/self/cgroup").read_text().strip()
    if not membership.startswith("0::/") or "\n" in membership:
        raise ValueError("Expected unified cgroup v2 membership")
    directory = Path("/sys/fs/cgroup") / membership[4:]
    observation = {
        name: (directory / name).read_text().strip()
        for name in ("memory.max", "memory.swap.max", "pids.max", "cpu.max")
    }
    for name, limit in (
        ("rlimit_cpu", resource.RLIMIT_CPU),
        ("rlimit_fsize", resource.RLIMIT_FSIZE),
        ("rlimit_core", resource.RLIMIT_CORE),
    ):
        observation[name] = list(resource.getrlimit(limit))
    return observation


def validate(profile: str, observation: dict) -> None:
    expected = {
        "memory.max": str((12 if profile == "build" else 6) * 1024**3),
        "memory.swap.max": "0",
        "pids.max": "256",
        "rlimit_cpu": [600, 600] if profile == "build" else [240, 240],
        "rlimit_fsize": [2 * 1024**3] * 2 if profile == "build" else [20 * 1024**3] * 2,
        "rlimit_core": [0, 0],
    }
    for name, value in expected.items():
        if observation.get(name) != value:
            raise ValueError(f"{name}: effective limit does not match {profile} profile")
    cpu_limit = observation.get("cpu.max")
    if not isinstance(cpu_limit, str):
        raise ValueError("cpu.max: expected finite quota and period")
    fields = cpu_limit.split()
    if len(fields) != 2 or not all(field.isdecimal() for field in fields):
        raise ValueError("cpu.max: expected finite quota and period")
    quota, period = map(int, fields)
    if period <= 0 or quota != 4 * period:
        raise ValueError("cpu.max: expected exactly four CPU equivalents")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", choices=("build", "runtime"))
    parser.add_argument("--snapshot", help="Check a saved observation instead of the live process")
    arguments = parser.parse_args()
    try:
        observation = (
            json.loads(Path(arguments.snapshot).read_text())
            if arguments.snapshot else observe()
        )
        if not isinstance(observation, dict):
            raise ValueError("Expected a resource observation object")
        validate(arguments.profile, observation)
    except (OSError, ValueError) as error:
        print(f"FAIL: resource limits: {error}", file=sys.stderr)
        return 1
    print(f"PASS: effective {arguments.profile} cgroup and inherited resource limits")
    print(json.dumps(observation, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
