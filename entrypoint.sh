#!/bin/sh
# When the first argument is "ssh", log the invocation timestamp and merge
# SSH's verbose output (stderr) into stdout so docker logs captures it.
# Pass -V through to ssh so "docker run kitsuyui/docker-ssh -V" prints the version.
# All other commands (e.g. the keygen sh script) run unmodified.
if [ "${1:-}" = "-V" ]; then
    exec ssh -V
fi
if [ "${1:-}" = "ssh" ]; then
    printf '%s [docker-ssh] starting: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
    exec "$@" -v 2>&1
fi
exec "$@"
