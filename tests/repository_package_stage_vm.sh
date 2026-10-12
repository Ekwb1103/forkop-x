#!/bin/sh
set -eu
[ "${FORKOP_TEST_VM:-}" = 1 ] || { echo 'Set FORKOP_TEST_VM=1' >&2; exit 1; }
ubus call system board | grep -qi VMware || { echo 'VMware VM required' >&2; exit 1; }
command -v apk >/dev/null || { echo 'APK VM required' >&2; exit 1; }
lib=${FORKOP_TEST_LIB:-/tmp/forkop-repository-stage-lib}
work=$(mktemp -d /tmp/forkop-repository-stage-test.XXXXXX)
mkdir "$work/bin"
export FORKOP_TEST_REAL_APK=$(command -v apk)
export FORKOP_TEST_APK_EVENTS="$work/apk.events"
export FORKOP_TEST_APK_REPOSITORIES="$work/repositories"
arch=$(apk --print-arch)
printf '%s\n' "https://mirror.51343.ru/forkop/mirror/current/$arch/packages.adb" > "$FORKOP_TEST_APK_REPOSITORIES"
cat > "$work/bin/apk" <<'WRAP'
#!/bin/sh
printf '%s\n' "$*" >> "$FORKOP_TEST_APK_EVENTS"
case "${1:-}" in
    update|fetch) exec "$FORKOP_TEST_REAL_APK" --repositories-file "$FORKOP_TEST_APK_REPOSITORIES" --allow-untrusted "$@" ;;
    adbdump|info|--print-arch|--allow-untrusted) exec "$FORKOP_TEST_REAL_APK" "$@" ;;
    *) echo 'Package mutation forbidden in staging test' >&2; exit 99 ;;
esac
WRAP
chmod 755 "$work/bin/apk"
apk info -v > "$work/packages.before" 2>/dev/null
sha256sum /etc/config/forkop /etc/config/sing-box > "$work/config.before.sha256"
run_stage() {
    PATH="$work/bin:$PATH" FORKOP_LIB="$lib" ucode -L "$lib" \
        "$lib/components/action.uc" repository-package-stage-fixture luci-app-forkop "$1"
}
fail() { echo "FAIL: $*; evidence: $work" >&2; exit 1; }
run_stage 2.1.3 > "$work/success.json" 2> "$work/success.err" || fail 'exact repository package could not be staged'
[ "$(jsonfilter -i "$work/success.json" -e '@.name')" = luci-app-forkop ] || fail 'wrong package identity'
[ "$(jsonfilter -i "$work/success.json" -e '@.version')" = 2.1.3 ] || fail 'wrong package revision'
path=$(jsonfilter -i "$work/success.json" -e '@.path')
[ -s "$path" ] || fail 'staged archive missing'
if run_stage 0.0.0_rc999999 > "$work/missing.json" 2> "$work/missing.err"; then
    fail 'unavailable exact package revision accepted'
fi
if grep -Eq 'Type error|Syntax error|Near here' "$work/success.err" "$work/missing.err"; then
    fail 'staging crashed instead of returning a controlled result'
fi
grep -q 'fetch .*luci-app-forkop' "$work/apk.events" || fail 'repository fetch was not reached'
apk info -v > "$work/packages.after" 2>/dev/null
cmp "$work/packages.before" "$work/packages.after" || fail 'installed packages changed'
sha256sum -c "$work/config.before.sha256" || fail 'configuration changed'
echo "PASS: exact repository package staging and unavailable-version rejection; evidence: $work"
