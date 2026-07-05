#!/usr/bin/env bash
# Test that the varlink-rust generator rejects malformed .varlink input.
# $1 = rlocationpath to varlink_rust_generator (resolved via $RUNFILES_DIR or $TEST_SRCDIR)
set -euo pipefail

RUNFILES="${RUNFILES_DIR:-$TEST_SRCDIR}"
GENERATOR="$RUNFILES/$1"

MALFORMED="$TEST_TMPDIR/bad.varlink"
cat > "$MALFORMED" <<'EOF'
this is not valid varlink !!!
method NotAnInterface
EOF

if "$GENERATOR" "$MALFORMED" >/dev/null 2>&1; then
    echo "ERROR: generator should have exited non-zero on malformed input" >&2
    exit 1
fi

echo "OK: generator rejected malformed input (exit $?)"
