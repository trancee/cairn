"""Source identity and explicit pre-cutover native guard selection."""

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
        DIRECTORY / "maude_image.py",
        DIRECTORY / "maude_candidate.py",
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


def select_proxy(candidate: Path | None = None) -> tuple[Path, str | None]:
    selected = str(candidate) if candidate is not None else os.environ.get("CAIRN_MAUDE_GUARD_CANDIDATE")
    if selected is None:
        return DIRECTORY / "maude_boundary.py", None
    if not selected or not Path(selected).is_absolute():
        raise GuardError("native guard candidate requires an absolute executable path")
    try:
        proxy = Path(selected).resolve(strict=True)
        usable = proxy.is_file() and os.access(proxy, os.X_OK)
    except (OSError, ValueError) as error:
        raise GuardError("native guard candidate unavailable; build the maintained guard") from error
    if not usable:
        raise GuardError("native guard candidate unavailable; build the maintained guard")
    return proxy, source_identity()
