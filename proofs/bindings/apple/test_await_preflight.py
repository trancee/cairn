import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name("await-preflight.py")
spec = importlib.util.spec_from_file_location("await_preflight", SCRIPT)
await_preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(await_preflight)

SUFFIX = "benign-preflight / benign-probes"


def job(name, status="completed", conclusion="success"):
    return {"name": name, "status": status, "conclusion": conclusion}


def page(*jobs):
    return {"total_count": len(jobs), "jobs": list(jobs)}


class FakeClock:
    def __init__(self):
        self.now = 0.0
        self.sleeps = []

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.now += seconds


class PreflightStateTest(unittest.TestCase):
    def test_successful_nested_preflight_is_accepted(self):
        state = await_preflight.preflight_state(page(
            job("kotlin-analysis / prepare (codeql)", "in_progress", None),
            job(f"kotlin-analysis / {SUFFIX}"),
        ), SUFFIX)

        self.assertEqual(state, "success")

    def test_directly_dispatched_preflight_name_is_accepted(self):
        self.assertEqual(await_preflight.preflight_state(page(job(SUFFIX)), SUFFIX), "success")

    def test_unfinished_or_missing_preflight_is_pending(self):
        for jobs in [
            page(job(SUFFIX, "queued", None)),
            page(job(SUFFIX, "in_progress", None)),
            page(job("kotlin-analysis / prepare (codeql)", "in_progress", None)),
        ]:
            with self.subTest(jobs=jobs):
                self.assertEqual(await_preflight.preflight_state(jobs, SUFFIX), "pending")

    def test_any_non_success_conclusion_is_a_failure(self):
        for conclusion in [
            "failure", "cancelled", "skipped", "timed_out", "neutral", "action_required", None,
        ]:
            with self.subTest(conclusion=conclusion):
                state = await_preflight.preflight_state(
                    page(job(SUFFIX, "completed", conclusion)), SUFFIX)

                self.assertEqual(state, "failure")

    def test_name_must_match_a_whole_path_segment(self):
        state = await_preflight.preflight_state(page(job(f"other-{SUFFIX}")), SUFFIX)

        self.assertEqual(state, "pending")

    def test_ambiguous_preflights_fail_closed(self):
        state = await_preflight.preflight_state(page(
            job(f"one / {SUFFIX}"), job(f"two / {SUFFIX}"),
        ), SUFFIX)

        self.assertEqual(state, "failure")

    def test_truncated_job_listing_fails_closed(self):
        listing = page(job(SUFFIX))
        listing["total_count"] = 101

        self.assertEqual(await_preflight.preflight_state(listing, SUFFIX), "failure")


class AwaitPreflightTest(unittest.TestCase):
    def test_waits_until_the_preflight_succeeds(self):
        clock = FakeClock()
        listings = iter([
            page(job(SUFFIX, "queued", None)),
            page(job(SUFFIX, "in_progress", None)),
            page(job(SUFFIX)),
        ])

        result = await_preflight.await_preflight(
            lambda: next(listings), SUFFIX, seconds=60, interval=5,
            monotonic=clock.monotonic, sleep=clock.sleep)

        self.assertEqual(result, "success")
        self.assertEqual(clock.sleeps, [5, 5])

    def test_failed_preflight_stops_waiting_immediately(self):
        clock = FakeClock()

        result = await_preflight.await_preflight(
            lambda: page(job(SUFFIX, "completed", "failure")), SUFFIX, seconds=60, interval=5,
            monotonic=clock.monotonic, sleep=clock.sleep)

        self.assertEqual(result, "failure")
        self.assertEqual(clock.sleeps, [])

    def test_pending_preflight_times_out_as_failure(self):
        clock = FakeClock()

        result = await_preflight.await_preflight(
            lambda: page(job(SUFFIX, "in_progress", None)), SUFFIX, seconds=12, interval=5,
            monotonic=clock.monotonic, sleep=clock.sleep)

        self.assertEqual(result, "timeout")
        self.assertLessEqual(clock.now, 12)

    def test_failed_poll_is_reported_and_retried_within_the_same_deadline(self):
        failures = [
            (subprocess.CalledProcessError(1, ["gh"], stderr="gh: HTTP 502\nsecond line\n"),
             "DIAGNOSTIC: preflight poll unavailable: CalledProcessError exit 1: gh: HTTP 502\n"),
            (subprocess.TimeoutExpired(["gh"], 60),
             "DIAGNOSTIC: preflight poll unavailable: TimeoutExpired\n"),
            (OSError("missing"), "DIAGNOSTIC: preflight poll unavailable: OSError\n"),
            (json.JSONDecodeError("bad", "", 0),
             "DIAGNOSTIC: preflight poll unavailable: JSONDecodeError\n"),
        ]
        for failure, message in failures:
            with self.subTest(failure=type(failure).__name__):
                clock = FakeClock()
                results = iter([failure, page(job(SUFFIX))])

                def fetch():
                    result = next(results)
                    if isinstance(result, Exception):
                        raise result
                    return result

                errors = io.StringIO()
                with mock.patch.object(sys, "stderr", errors):
                    result = await_preflight.await_preflight(
                        fetch, SUFFIX, seconds=60, interval=5,
                        monotonic=clock.monotonic, sleep=clock.sleep)

                self.assertEqual(result, "success")
                self.assertEqual(clock.sleeps, [5])
                self.assertEqual(errors.getvalue(), message)

    def test_persistently_failing_poll_times_out_at_the_unchanged_deadline(self):
        clock = FakeClock()

        def fetch():
            raise subprocess.CalledProcessError(1, ["gh"], stderr="gh: HTTP 502\n")

        with mock.patch.object(sys, "stderr", io.StringIO()):
            result = await_preflight.await_preflight(
                fetch, SUFFIX, seconds=12, interval=5,
                monotonic=clock.monotonic, sleep=clock.sleep)

        self.assertEqual(result, "timeout")
        self.assertLessEqual(clock.now, 12)

    def test_poll_diagnostic_is_one_bounded_printable_line(self):
        error = subprocess.CalledProcessError(1, ["gh"], stderr="\x1b[31m" + "x" * 500 + "\nnext")

        message = await_preflight.describe_poll_error(error)

        self.assertTrue(message.startswith("CalledProcessError exit 1: "))
        self.assertTrue(message.isprintable())
        self.assertLessEqual(len(message), 240)

    def test_main_reports_success_and_failure_exit_codes(self):
        for listing, code, message in [
            (page(job(SUFFIX)), 0, "PASS: same-run benign preflight succeeded before the bounded cell\n"),
            (page(job(SUFFIX, "completed", "failure")), 1, "FAIL: same-run benign preflight failure\n"),
        ]:
            with self.subTest(code=code):
                output = io.StringIO()
                with (
                    mock.patch.object(await_preflight, "fetch_jobs", return_value=listing),
                    mock.patch.object(sys, "argv", [str(SCRIPT), "--job", SUFFIX]),
                    mock.patch.object(sys, "stdout", output),
                    mock.patch.object(sys, "stderr", output),
                ):

                    result = await_preflight.main()

                self.assertEqual(result, code)
                self.assertEqual(output.getvalue(), message)

    def test_fetch_uses_the_current_run_attempt_listing(self):
        environment = {
            "GITHUB_REPOSITORY": "owner/repo", "GITHUB_RUN_ID": "42", "GITHUB_RUN_ATTEMPT": "3",
        }
        completed = mock.Mock(stdout=json.dumps(page(job(SUFFIX))))
        with (
            mock.patch.dict("os.environ", environment, clear=True),
            mock.patch("subprocess.run", return_value=completed) as run,
        ):

            listing = await_preflight.fetch_jobs()

        self.assertEqual(listing, page(job(SUFFIX)))
        self.assertEqual(run.call_args.args[0], [
            "gh", "api", "repos/owner/repo/actions/runs/42/attempts/3/jobs?per_page=100",
        ])
        self.assertTrue(run.call_args.kwargs["check"])


if __name__ == "__main__":
    unittest.main()
