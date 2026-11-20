#!/bin/bash
# Pull the phone's own device tree over adb and turn it into the SoC boot-args HakiOS needs on this
# device (tools/soc-args-caf.py). Needs the phone in Android with adb. /sys/firmware/fdt is readable by
# everybody on most ROMs; where only root can read it the tree is copied under su to a staging file the
# shell can read, pulled from there, and the staging file is removed again.
#
# The tree of the phone's own Android is a Qualcomm CAF one, which the common repository's tools/soc-args.py
# cannot read (it looks for mainline-style nodes); this repository's tools/soc-args-caf.py reads the CAF
# names (docs/port-notes.md, section 4).
set -e -o pipefail
here=$(cd "$(dirname "$0")" && pwd)             # before the cd: $0 may be a relative path
cd "$here/../.."
PATH=$PWD/tools/macos-bin/platform-tools:$PATH
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if ! adb pull /sys/firmware/fdt "$tmp/fdt" >/dev/null 2>&1; then
	stage=/data/local/tmp/hakios-fdt
	adb shell "su -c 'cat /sys/firmware/fdt > $stage && chmod 644 $stage'" >/dev/null 2>&1 || true
	got=0; adb pull "$stage" "$tmp/fdt" >/dev/null 2>&1 || got=1
	adb shell "su -c 'rm -f $stage'" >/dev/null 2>&1 || true
	[ "$got" -eq 0 ] || { echo "pull-soc.sh: cannot read /sys/firmware/fdt over adb, with or without su"; exit 1; }
fi
# made aside and copied over, so that a failure leaves the soc.args that was there
python3 tools/soc-args-caf.py "$tmp/fdt" > "$tmp/soc.args"
cp "$tmp/soc.args" "$here/soc.args"
cat "$here/soc.args"
echo "pull-soc.sh: wrote $here/soc.args"
