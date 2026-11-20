#!/bin/bash
# Pull the phone's own firmware out of its Android into the fw-*/ directories at the top of the
# repository (never committed: it is the vendor's). The phone is on adb, in Android.
#
# This is the Mi A2's list: its GPU is an Adreno 512, its radio a WCN3990, its motor is in the PMIC
# (there is no I2C motor to pull), and its audio is the PMIC's own codec with the SoundWire.
# The files are the ones the drivers of this port will ask for; the names are the ones the phone's
# own Android uses (see docs/port-notes.md for where each of them is).
set -e
cd "$(dirname "$0")/../.."
pull() { # DIR SOURCE...  (missing files are told, not fatal)
	local dir=$1; shift
	mkdir -p "$dir"
	for f in "$@"; do adb pull "$f" "$dir/" >/dev/null 2>&1 || echo "pull-firmware.sh: $f: not on the phone"; done
	echo "pull-firmware.sh: $dir: $(ls -1 "$dir" | wc -l | tr -d ' ') files"
}
adb get-state >/dev/null

# the GPU: an Adreno 512 (A5xx). The firmware of an A5xx is named a5xx, not a6xx as on the reference phone.
pull fw-gpu /vendor/firmware/a530_pm4.fw /vendor/firmware/a530_pfp.fw /vendor/firmware/a512_zap.mdt \
	/vendor/firmware/a512_zap.b00 /vendor/firmware/a512_zap.b01 /vendor/firmware/a512_zap.b02

# the Wi-Fi and Bluetooth firmware: a WCN3990, so the files are wcn3990_* (the reference phone's are wpss_*)
pull fw-wifi /vendor/firmware_mnt/image/wcn3990_*.mdt /vendor/firmware_mnt/image/wcn3990_*.b02 \
	/vendor/firmware_mnt/image/wcn3990_*.b03 /vendor/firmware_mnt/image/wcn3990_*.b04 \
	/vendor/firmware_mnt/image/wcn3990_*.b05 /vendor/firmware_mnt/image/wcn3990_*.b06 \
	/vendor/firmware_mnt/image/wcn3990_*.b07

# the audio DSP: the aDSP of this chip (LPASS at 0x15700000)
pull fw-audio /vendor/firmware_mnt/image/adsp.mdt $(for i in $(seq -w 2 36); do echo /vendor/firmware_mnt/image/adsp.b$i; done)

# the modem: the QDSP6 of this chip
pull fw-modem /vendor/firmware_mnt/image/modem.mdt $(for i in $(seq -w 0 28); do echo /vendor/firmware_mnt/image/modem.b$i; done)
mkdir -p fw-modem/image && adb pull /vendor/firmware_mnt/image fw-modem/ >/dev/null 2>&1 && echo "pull-firmware.sh: fw-modem/image: the modem's own files (TFTP)"

# the cameras: this phone has three (a rear ov02a10 and two front variants)
pull fw-camera $(adb shell ls /vendor/lib64/camera/com.qti.sensormodule.hakios_*.bin /vendor/lib64/camera/com.qti.tuned.hakios_*.bin 2>/dev/null | tr -d '\r')

echo "pull-firmware.sh: done; Wi-Fi also wants fw-wifi/mac (the radio's address) and fw-wifi/network (the network's name and passphrase)"
echo "pull-firmware.sh: note -- this phone's vibration motor is the PM660's own ERM driver (USID 1, SPMI 0xc000): there is no"
echo "pull-firmware.sh: file to pull for it, and the same goes for the audio, which is the PMIC's own codec."
