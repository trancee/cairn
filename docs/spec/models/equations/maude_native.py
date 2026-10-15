"""Source identity and executable selection for the maintained native guard."""

import hashlib
import os
from pathlib import Path

from .maude_runner import GuardError


DIRECTORY = Path(__file__).resolve().parent
NATIVE_DIRECTORY = DIRECTORY / "native-proxy"
ROOT = DIRECTORY.parents[3]


def source_inputs() -> tuple[Path, ...]:
    return (
        ROOT / "rust-toolchain.toml",
        DIRECTORY / "signature.py",
        DIRECTORY / "maude_module.py",
        DIRECTORY / "maude_native.py",
        DIRECTORY / "maude_runner.py",
        *(NATIVE_DIRECTORY / name for name in (
            "Cargo.toml", "Cargo.lock", "build.rs", "inventory.py",
        )),
        *sorted((NATIVE_DIRECTORY / "src").rglob("*.rs")),
    )


def source_identity() -> str:
    digest = hashlib.sha256()
    try:
        for source in source_inputs():
            digest.update(source.relative_to(ROOT).as_posix().encode())
            digest.update(b"\0")
            digest.update(source.read_bytes())
            digest.update(b"\0")
    except (OSError, UnicodeError) as error:
        raise GuardError("native guard source identity inputs unavailable") from error
    return digest.hexdigest()


def select_proxy(proxy: Path | None = None) -> tuple[Path, str]:
    if proxy is None:
        target = os.environ.get("CARGO_TARGET_DIR")
        if target == "":
            raise GuardError("native guard CARGO_TARGET_DIR must not be empty")
        directory = Path(target) if target is not None else ROOT / "target/native-proxy"
        proxy = (directory / "release/cairn-maude-proxy").absolute()
    if not proxy.is_absolute():
        raise GuardError("native guard requires an absolute executable path")
    try:
        proxy = proxy.resolve(strict=True)
        usable = proxy.is_file() and os.access(proxy, os.X_OK)
    except (OSError, ValueError) as error:
        raise GuardError("native guard unavailable; build with scripts/check.sh") from error
    if not usable:
        raise GuardError("native guard unavailable; build with scripts/check.sh")
    return proxy, source_identity()
