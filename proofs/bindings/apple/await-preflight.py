import argparse
import json
import os
import subprocess
import sys
import time

PAGE_SIZE = 100


def preflight_state(listing: dict, suffix: str) -> str:
    jobs = listing["jobs"]
    if listing["total_count"] > PAGE_SIZE or listing["total_count"] != len(jobs):
        return "failure"
    matches = [
        job for job in jobs if job["name"] == suffix or job["name"].endswith(f" / {suffix}")
    ]
    if len(matches) > 1:
        return "failure"
    if not matches or matches[0]["status"] != "completed":
        return "pending"
    return "success" if matches[0]["conclusion"] == "success" else "failure"


def await_preflight(fetch, suffix, seconds, interval, monotonic=time.monotonic, sleep=time.sleep):
    deadline = monotonic() + seconds
    while True:
        state = preflight_state(fetch(), suffix)
        if state != "pending":
            return state
        if monotonic() + interval > deadline:
            return "timeout"
        sleep(interval)


def fetch_jobs() -> dict:
    repository = os.environ["GITHUB_REPOSITORY"]
    run = os.environ["GITHUB_RUN_ID"]
    attempt = os.environ["GITHUB_RUN_ATTEMPT"]
    result = subprocess.run(
        ["gh", "api", f"repos/{repository}/actions/runs/{run}/attempts/{attempt}/jobs?per_page={PAGE_SIZE}"],
        capture_output=True, text=True, check=True, timeout=60,
    )
    return json.loads(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description="Wait for the same-run benign preflight")
    parser.add_argument("--job", required=True)
    parser.add_argument("--seconds", type=int, default=1500)
    parser.add_argument("--interval", type=int, default=5)
    args = parser.parse_args()
    state = await_preflight(fetch_jobs, args.job, args.seconds, args.interval)
    if state == "success":
        print("PASS: same-run benign preflight succeeded before the bounded cell")
        return 0
    print(f"FAIL: same-run benign preflight {state}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
