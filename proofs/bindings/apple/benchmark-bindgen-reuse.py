import argparse
import hashlib
import json
import math
import os
import platform
import statistics
import subprocess
import time
from pathlib import Path


BASELINE_REVISION = "8b4c2d623cfa0a618cb6b92522488cccbb90fd4d"
BINARY = "uniffi-bindgen-kotlin-multiplatform"
PREAMBLE = "INFO: approved debug-profile generator installation; SDK profiles unchanged"


def artifact_counts(path, allow_preamble=False):
    counts = {"fresh": 0, "compiled": 0}
    generator_count = 0
    completed = False
    with path.open() as output:
        for line in output:
            if allow_preamble and line.rstrip("\n") == PREAMBLE:
                allow_preamble = False
                continue
            message = json.loads(line)
            if not isinstance(message, dict) or not isinstance(message.get("reason"), str):
                raise ValueError("invalid Cargo message")
            if message["reason"] == "compiler-artifact":
                fresh = message.get("fresh")
                target = message.get("target")
                if type(fresh) is not bool or not isinstance(target, dict):
                    raise ValueError("invalid Cargo artifact")
                counts["fresh" if fresh else "compiled"] += 1
                if target.get("name") == BINARY:
                    if fresh:
                        raise ValueError("generator was not freshly compiled")
                    generator_count += 1
            elif message["reason"] == "build-finished":
                if completed or message.get("success") is not True:
                    raise ValueError("Cargo build did not succeed")
                completed = True
            elif message["reason"] not in ("compiler-message", "build-script-executed"):
                raise ValueError("unknown Cargo message")
    if not completed or generator_count != 1:
        raise ValueError("expected one freshly compiled generator")
    return counts


def checksum(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def prepare_vendor_config(home, tools):
    config = home / "cargo-offline/config.toml"
    expected = tools / "cargo-inputs/vendor.toml"
    if config.is_symlink():
        if os.readlink(config) != str(expected):
            raise ValueError("offline vendor configuration symlink mismatch")
    elif config.exists():
        raise ValueError("offline vendor configuration is not the frozen-input symlink")
    else:
        config.symlink_to(expected)


def summarize(reports):
    if len(reports) < 3:
        raise ValueError("comparison requires at least three independent paired reports")
    identity_fields = (
        "baseline_revision", "platform", "python", "cpu_count", "rust",
        "candidate_adapter_sha256", "fixture_config_sha256",
        "fixture_source_sha256", "fixture_lock_sha256", "generator_lock_sha256",
        "benchmark_sha256",
    )
    identity = {field: reports[0][field] for field in identity_fields}
    if identity["baseline_revision"] != BASELINE_REVISION:
        raise ValueError("comparison baseline revision mismatch")
    orders = set()
    ratios = []
    for report in reports:
        if {field: report[field] for field in identity_fields} != identity:
            raise ValueError("comparison environments or source inputs differ")
        order = tuple(report["order"])
        if order not in (("baseline", "candidate"), ("candidate", "baseline")):
            raise ValueError("invalid comparison order")
        orders.add(order)
        samples = report["samples"]
        for mode in ("baseline", "candidate"):
            sample = samples[mode]
            seconds = sample["seconds"]
            if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds <= 0:
                raise ValueError("invalid comparison duration")
            if sample["architecture"] != "arm64" or sample["explicit_target"] is not (
                mode == "candidate"
            ):
                raise ValueError("comparison architecture or target mismatch")
            counts = sample["artifacts"]
            if any(type(counts[key]) is not int or counts[key] < 0 for key in ("fresh", "compiled")):
                raise ValueError("invalid comparison artifact counts")
            if counts["compiled"] < 1:
                raise ValueError("comparison lacks fresh compilation")
        if samples["baseline"]["artifacts"]["fresh"] != 0:
            raise ValueError("comparison baseline reused artifacts")
        if samples["candidate"]["artifacts"]["fresh"] < 1:
            raise ValueError("comparison candidate did not reuse artifacts")
        ratios.append(samples["candidate"]["seconds"] / samples["baseline"]["seconds"])
    if len(orders) != 2:
        raise ValueError("comparison requires both execution orders")
    median = statistics.median(ratios)
    if median > 1.1:
        raise ValueError(f"median installation regression exceeds 10%: ratio {median:.4f}")
    return {
        **identity, "paired_ratios": ratios, "median_ratio": median,
        "median_reduction_percent": (1 - median) * 100,
        "regression_limit": 1.1,
    }


def measure(tools, home, output, mode):
    install = output / (mode + "-install")
    target = home / ("bindgen-baseline-target" if mode == "baseline" else "fixture-cargo-target")
    if install.exists() or install.is_symlink() or target.is_symlink() or (
        mode == "baseline" and target.exists()
    ):
        raise ValueError("benchmark output is not fresh")
    if mode == "candidate" and not target.is_dir():
        raise ValueError("fresh fixture compilation must precede the comparison")
    command = [str(tools / "rust/bin/cargo"), "install", "--debug"]
    if mode == "candidate":
        command = [str(tools / "generator-tools/cargo"), "install"]
    command.extend([
        "--locked", "--root", str(install), "--force",
        "--path", str(tools / "ubique/bindgen"), "--bin", BINARY,
        "uniffi_bindgen_kotlin_multiplatform", "--message-format=json",
    ])
    environment = {
        **os.environ, "CARGO_HOME": str(home / "cargo-offline"),
        "CARGO_TARGET_DIR": str(target), "CARGO_NET_OFFLINE": "true",
        "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
        "PATH": f"{tools}/generator-tools:{tools}/rust/bin:{tools}/daemon-jdk/bin:"
                "/usr/bin:/bin:/usr/sbin:/sbin",
    }
    started = time.monotonic()
    log = output / (mode + ".jsonl")
    with log.open("x") as stream:
        subprocess.run(command, env=environment, stdout=stream, check=True, timeout=600)
    elapsed = time.monotonic() - started
    counts = artifact_counts(log, allow_preamble=mode == "candidate")
    architecture = subprocess.run(
        ["/usr/bin/lipo", "-archs", str(install / "bin" / BINARY)],
        check=True, capture_output=True, text=True, timeout=5,
    ).stdout.strip()
    if architecture != "arm64":
        raise ValueError("installed generator architecture mismatch")
    return {
        "seconds": elapsed, "artifacts": counts, "architecture": architecture,
        "binary_sha256": checksum(install / "bin" / BINARY),
        "explicit_target": mode == "candidate",
    }


def main():
    parser = argparse.ArgumentParser(description="One bounded paired Cargo-install comparison")
    parser.add_argument("tools", type=Path, nargs="?")
    parser.add_argument("--order", choices=("baseline-first", "candidate-first"))
    parser.add_argument("--reports", type=Path, nargs="+", help="Validate and summarize paired reports")
    arguments = parser.parse_args()
    if arguments.reports:
        if arguments.tools or arguments.order:
            parser.error("report summary cannot also execute installation")
        try:
            reports = [json.loads(path.read_text()) for path in arguments.reports]
            print(json.dumps(summarize(reports), indent=2))
        except (KeyError, TypeError):
            raise SystemExit("FAIL: bindgen summary evidence structure invalid")
        except ValueError as error:
            raise SystemExit(f"FAIL: bindgen summary evidence: {error}")
        except OSError as error:
            raise SystemExit(f"FAIL: bindgen summary I/O errno {error.errno}")
        return
    if arguments.tools != Path("/opt/cairn-apple-tools"):
        parser.error("comparison requires the frozen hosted tool root")
    if not arguments.order:
        parser.error("comparison order is required")
    tools = arguments.tools
    if not os.environ.get("HOME"):
        parser.error("comparison scratch home is required")
    home = Path(os.environ["HOME"])
    output = home / "bindgen-benchmark"
    try:
        output.mkdir()
        prepare_vendor_config(home, tools)
        rust = subprocess.run(
            [str(tools / "rust/bin/rustc"), "--version", "--verbose"],
            check=True, capture_output=True, text=True, timeout=5,
        ).stdout
        if not rust.startswith("rustc 1.97.1 ") or "host: aarch64-apple-darwin\n" not in rust:
            raise ValueError("comparison toolchain differs from the committed baseline")
        modes = ("baseline", "candidate")
        if arguments.order == "candidate-first":
            modes = tuple(reversed(modes))
        samples = {mode: measure(tools, home, output, mode) for mode in modes}
        if samples["baseline"]["artifacts"]["fresh"] != 0:
            raise ValueError("baseline unexpectedly reused compiled artifacts")
        if samples["candidate"]["artifacts"]["fresh"] == 0:
            raise ValueError("candidate did not reuse fixture compilation artifacts")
        result = {
            "baseline_revision": BASELINE_REVISION, "order": list(modes),
            "platform": platform.platform(), "python": platform.python_version(),
            "cpu_count": os.cpu_count(), "rust": rust,
            "candidate_adapter_sha256": checksum(tools / "generator-tools/cargo"),
            "fixture_config_sha256": checksum(tools / "fixture/sdk/apple.gradle.kts"),
            "fixture_source_sha256": checksum(tools / "fixture/sdk/rust/src/lib.rs"),
            "fixture_lock_sha256": checksum(tools / "fixture/sdk/rust/Cargo.lock"),
            "generator_lock_sha256": checksum(tools / "ubique/Cargo.lock"),
            "benchmark_sha256": checksum(Path(__file__)),
            "samples": samples,
            "ratio": samples["candidate"]["seconds"] / samples["baseline"]["seconds"],
        }
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, sort_keys=True))
    except subprocess.TimeoutExpired:
        raise SystemExit("FAIL: bindgen comparison child deadline exceeded")
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"FAIL: bindgen comparison child exit {error.returncode}; diagnostics retained")
    except OSError as error:
        raise SystemExit(f"FAIL: bindgen comparison I/O errno {error.errno}")
    except ValueError as error:
        raise SystemExit(f"FAIL: bindgen comparison evidence: {error}")


if __name__ == "__main__":
    main()
