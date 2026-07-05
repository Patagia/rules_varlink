#!/usr/bin/env bash
# Integration test: start the ping server, call it via the client, assert the echo.
set -euo pipefail

# The test script, server, and client are all in the root package, so they share
# the same runfiles directory.
DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="$DIR/server"
CLIENT="$DIR/client"
# Unix socket paths are limited to 108 bytes; $TEST_TMPDIR can exceed that.
SOCK_PATH="/tmp/vl-$$.sock"
SOCK="unix:$SOCK_PATH"
MSG="hello-varlink-test"

"$SERVER" "$SOCK" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -f "$SOCK_PATH"' EXIT

# Wait up to 5 s for the Unix socket to appear.
for _ in $(seq 1 50); do
    [ -S "$SOCK_PATH" ] && break
    sleep 0.1
done
if [ ! -S "$SOCK_PATH" ]; then
    echo "ERROR: server socket never appeared at $SOCK_PATH" >&2
    exit 1
fi

RESULT=$("$CLIENT" "$SOCK" "$MSG")
if [ "$RESULT" != "$MSG" ]; then
    echo "ERROR: expected pong='$MSG', got '$RESULT'" >&2
    exit 1
fi

echo "OK: pong='$RESULT'"
