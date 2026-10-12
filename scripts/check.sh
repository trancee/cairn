#!/usr/bin/env bash
# Fast local gates. Slow Tamarin replays stay opt-in: see docs/spec/models/ENVIRONMENT.md.
set -euo pipefail
cd "$(dirname "$0")/.."

git diff --check
git diff --cached --check

python3 docs/spec/models/check_certificates.py
python3 -m unittest discover -s docs/spec/models -p 'test_*.py'
python3 -m unittest discover -s docs/spec/models/lifecycle -p 'test_*.py'

if command -v actionlint >/dev/null; then
  actionlint .github/workflows/*.yml
else
  echo "skip: actionlint not installed" >&2
fi

lean="${LEAN:-$(command -v lean || true)}"
if [ -n "$lean" ]; then
  python3 docs/spec/models/lifecycle/check.py --lean "$lean"
else
  echo "skip: set LEAN=<path to pinned lean> to run the lifecycle gate" >&2
fi

if [ "${REPLAY:-0}" = 1 ]; then
  python3 docs/spec/models/replay.py --timeout 180
  python3 docs/spec/models/replay.py --disclosure-sources --timeout 180
  for target in kem_ciphertext_origin fresh_dk_origin encrypted_origin extract_origin \
      ratchet_key_origin session_key_origin initial_ck_secret fresh_ss_origin \
      encrypted_ct_tail_encapsulated; do
    python3 docs/spec/models/replay.py --disclosure-sources --target "$target" --timeout 180
  done
  python3 docs/spec/models/mutation.py --timeout 180
  python3 docs/spec/models/mutation.py --mutation NO_PREFIX_GUARD --timeout 180
fi
