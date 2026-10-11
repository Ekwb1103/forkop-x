#!/bin/sh
set -eu
[ "${FORKOP_TEST_VM:-}" = 1 ] || exit 1
ubus call system board | grep -qi VMware || exit 1
work=${FORKOP_STORAGE_TEST_WORK:-/tmp/storage-review-vm-20261009}
lib=/usr/lib/forkop
action=$lib/components/action.uc
manager=$(command -v apk || command -v opkg)
curl=$(command -v curl)
export FORKOP_STORAGE_TEST_WORK="$work" FORKOP_STORAGE_REAL_MANAGER="$manager" FORKOP_STORAGE_REAL_CURL="$curl"
fail() { echo "FAIL: $*; evidence: $work" >&2; exit 1; }
packages() { if command -v apk >/dev/null; then "$manager" info -v; else "$manager" list-installed; fi; }
[ -f "$work/x-1.0.2.json" ] || fail 'stage validated mirror manifest first'
if command -v apk >/dev/null; then archive=$work/sing-box-x_1.0.2-r1_x86_64.apk; version=1.0.2-r1
else archive=$work/sing-box-x_1.0.2-1_x86_64.ipk; version=1.0.2-1; fi
[ -s "$archive" ] || fail 'exact original rollback archive missing'
# The operator validates catalog identity, architecture, length and SHA-256
# before staging; the real action validates them again through cached transport.
ucode -L "$lib" "$action" sing-box-package-info-fixture "$archive" sing-box-x "$version" >"$work/package-info.json"
sing-box version | head -n 1 | grep -q '1.14.2-x-1.0.2' || fail 'unexpected initial core'
[ "$(forkop get_status | jsonfilter -e '@.running')" = 1 ] || fail 'initial runtime stopped'
packages >"$work/packages.test-before"
ubus call service list >"$work/services.test-before.json"
cp /etc/config/forkop "$work/forkop.test-before.uci"
cp /etc/config/sing-box "$work/sing-box.test-before.uci"
sha256sum /usr/bin/sing-box "$action" >"$work/files.test-before.sha256"
df -Pk /usr/bin /tmp >"$work/df.test-before"
# Only the isolated model changes the baseline. All mutating cases below use
# the original action.uc. This is not a native read-only firmware filesystem.
awk '{ print; if ($0 == "function sing_box_existing_writable_bytes(previous) {") print "    return 0; // VM-only ROM baseline model"; }' "$action" >"$work/action-rom.uc"
mkdir -p "$work/bin"
cat >"$work/bin/curl" <<'EOF'
#!/bin/sh
output=; url=; want_output=0
for arg in "$@"; do
  if [ "$want_output" = 1 ]; then output=$arg; want_output=0; continue; fi
  case "$arg" in -o) want_output=1;; https://mirror.51343.ru/*) url=$arg;; esac
done
case "$url" in
  https://mirror.51343.ru/forkop/sing-box-x/latest.json|https://mirror.51343.ru/forkop/sing-box-x/releases/1.0.2/manifest.json)
    source=$FORKOP_STORAGE_TEST_WORK/x-1.0.2.json;;
  https://mirror.51343.ru/forkop/sing-box-x/releases/1.0.2/sing-box-x_1.0.2-r1_x86_64.apk)
    source=$FORKOP_STORAGE_TEST_WORK/sing-box-x_1.0.2-r1_x86_64.apk;;
  https://mirror.51343.ru/forkop/sing-box-x/releases/1.0.2/sing-box-x_1.0.2-1_x86_64.ipk)
    source=$FORKOP_STORAGE_TEST_WORK/sing-box-x_1.0.2-1_x86_64.ipk;;
  *) exec "$FORKOP_STORAGE_REAL_CURL" "$@";;
esac
[ -n "$output" ] || exit 2
cp "$source" "$output"
EOF
cat >"$work/bin/df" <<'EOF'
#!/bin/sh
case " $* " in
  *' -Pk '*'/usr/bin'*)
    free=7928
    if [ ! -x /usr/bin/sing-box ]; then
      if [ "$FORKOP_STORAGE_MODE" = post-shortage ]; then free=1000; else free=17000; fi
    fi
    printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 100000 90000 %s 90%% /\n' "$free"
    exit 0;;
esac
exec /bin/df "$@"
EOF
cat >"$work/bin/$(basename "$manager")" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FORKOP_STORAGE_TEST_WORK/manager-$FORKOP_STORAGE_MODE.log"
if [ "$FORKOP_STORAGE_MODE" = install-fault ]; then
  for arg in "$@"; do
    case "$arg" in */sing-box-x_1.0.2*.apk|*/sing-box-x_1.0.2*.ipk)
      case " $* " in *' add '*|*' install '*)
        if [ ! -e "$FORKOP_STORAGE_TEST_WORK/fault-fired" ]; then
          touch "$FORKOP_STORAGE_TEST_WORK/fault-fired"
          echo 'injected installation failure' >&2
          exit 42
        fi;; esac;;
    esac
  done
fi
exec "$FORKOP_STORAGE_REAL_MANAGER" "$@"
EOF
chmod 755 "$work/bin/"*
verify() {
  packages >"$work/packages.after-$FORKOP_STORAGE_MODE"
  cmp "$work/packages.test-before" "$work/packages.after-$FORKOP_STORAGE_MODE" || fail 'package/dependency revisions changed'
  sha256sum -c "$work/files.test-before.sha256" >/dev/null || fail 'binary or production backend changed'
  cmp /etc/config/forkop "$work/forkop.test-before.uci" || fail 'Forkop UCI changed'
  cmp /etc/config/sing-box "$work/sing-box.test-before.uci" || fail 'sing-box UCI changed'
  [ "$(forkop get_status | jsonfilter -e '@.running')" = 1 ] || fail 'runtime not restored'
  [ "$(ucode -L "$lib" "$lib/service/state.uc" sing-box-process-count)" = 1 ] || fail 'runtime process count'
  sing-box check -c /etc/sing-box/config.json >"$work/config-$FORKOP_STORAGE_MODE.log" 2>&1 || fail 'config invalid'
  nslookup example.com 127.0.0.1 >"$work/dns-$FORKOP_STORAGE_MODE.log" 2>&1 || fail 'DNS failed'
}
run() { PATH="$work/bin:$PATH" ucode -L "$lib" "$1" component-action sing_box install_x; }
export FORKOP_STORAGE_MODE=rom
: >"$work/manager-rom.log"
pid_before=$(pidof sing-box)
if run "$work/action-rom.uc" >"$work/rom.log" 2>&1; then fail 'ROM baseline unexpectedly fit'; fi
grep -q 'conservative installation reserve' "$work/rom.log" || fail 'wrong ROM failure'
[ "$(pidof sing-box)" = "$pid_before" ] || fail 'ROM rejection stopped runtime'
verify
echo 'PASS: modeled ROM preflight rejects 7928 KiB without package/service mutation'
# The tests below execute the untouched production backend and real package manager.
# df and mirror transport are controlled; real writable flash is not filled.
export FORKOP_STORAGE_MODE=writable
: >"$work/manager-writable.log"
run "$action" >"$work/writable.log" 2>&1 || fail 'writable low-space reinstall'
grep -q '^del sing-box-x$\|^remove sing-box-x$' "$work/manager-writable.log" || fail 'real removal not reached'
grep -q '^add .*sing-box-x_\|^install .*sing-box-x_' "$work/manager-writable.log" || fail 'real install not reached'
verify
echo 'PASS: stock writable preflight at 7928 KiB followed by real remove/install and healthy runtime'
export FORKOP_STORAGE_MODE=post-shortage
: >"$work/manager-post-shortage.log"
if run "$action" >"$work/post-shortage.log" 2>&1; then fail 'post-removal shortage accepted'; fi
grep -q 'previous sing-box variant was restored' "$work/post-shortage.log" || fail 'post-removal rollback not confirmed'
verify
echo 'PASS: real removal, simulated post-removal shortage, exact package/runtime rollback'
export FORKOP_STORAGE_MODE=install-fault
: >"$work/manager-install-fault.log"
rm -f "$work/fault-fired"
if run "$action" >"$work/install-fault.log" 2>&1; then fail 'install failure accepted'; fi
[ -e "$work/fault-fired" ] || fail 'install failure not reached'
grep -q 'previous sing-box variant was restored' "$work/install-fault.log" || fail 'install rollback not confirmed'
verify
echo 'PASS: installation fault after real removal restores exact package/runtime'
ubus call service list >"$work/services.after.json"
df -Pk /usr/bin /tmp >"$work/df.after"
echo "LOW_SPACE_MATRIX_COMPLETE; evidence: $work"
