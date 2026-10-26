#!/bin/sh
# VM-only Forkop init wrapper: fail the first start of the core whose version
# matches FORKOP_TEST_FAIL_START_VERSION (default: extended), then allow the
# rollback to use the real init script. Requires a dedicated marker path.
set -eu
marker="${FORKOP_TEST_START_FAILURE_MARKER:?missing test marker}"
pattern="${FORKOP_TEST_FAIL_START_VERSION:-*extended*}"
if [ "${1:-}" = start ] && [ ! -e "$marker" ]; then
  # shellcheck disable=SC2254
  case "$(sing-box version | head -n 1)" in
    $pattern)
      : >"$marker"
      echo 'injected startup failure' >&2
      exit 42
      ;;
  esac
fi
exec /etc/init.d/forkop "$@"
