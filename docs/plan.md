# The plan, in steps that can be checked

Each step says what is done when it is. A step is not done because the code was written: it is done when the thing it names
has been **seen**. Nothing in this list has been run on the phone.

The order is the one that works: the things that can be checked without a phone first, the things that need one last.

## Stage 0 -- the machine and the common repository (done)

| # | Step | Done when | State |
|---|---|---|---|
| 0.1 | the dependencies of the kernel build, without root | `xnu-deps/setup.sh --stage1` and `--stage2` finish | **done** |
| 0.2 | the common kernel builds | `tools/make-kernel.sh -j8` produces `hakios-kernel` | **done** |
| 0.3 | the loader, the RAM disk and the kernel run in QEMU | the log shows the loader's banner, `kernel.ver=`, "drivers built in", and "Hello from user space on Darwin!" | **done** |

## Stage 1 -- this phone's facts (done)

| # | Step | Done when | State |
|---|---|---|---|
| 1.1 | the phone's own device tree, built from the vendor kernel | `prebuilt/device-tree.dtb` is the tree of `jasmine-q-oss` and every address in `docs/port-notes.md` is read out of it | **done** |
| 1.2 | the SoC's boot-arguments | `tools/soc-args-caf.py` prints the nine `soc_*` values and `soc.args` holds them | **done** |
| 1.3 | what the common repository's `tools/soc-args.py` cannot read here | the difference is written down (`docs/port-notes.md`, section 4) | **done** |
| 1.4 | the configuration the project's own tools accept | `tools/hakios-device.py check jasmine_sprout` passes and `tools/hakios-config.py check` is happy | **done** |
| 1.5 | the kernel builds with that configuration | `tools/make-kernel.sh -j8` after `make jasmine_sprout_defconfig` | **done** |
| 1.6 | that kernel runs in QEMU | the log shows "9 drivers built in (.config)" and "Hello from user space on Darwin!" | **done** (with `thermal` left out: the thermal driver reads the reference phone's blocks, and QEMU's machine has none) |


## Stage 2 -- the kernel, in QEMU, as the phone's chip

The QEMU machine is not this phone's. The point of this stage is to make the **kernel** speak of this chip, and to see it do
so in a machine that can be run again and again.

| # | Step | Done when | State |
|---|---|---|---|
| 2.1 | a platform table for this chip in the loader | `xnuloader/loader.c` has `platform_jasmine_sprout` with this chip's `gic_dist` 0x17a00000, `gic_redist` **0x17b00000**, 8 cores, `core_shift` 8, `small_cores` 0x0f | to do |
| 2.2 | the device tree of the phone in the kernel's own device tree | the kernel's ADT (`loader.c:3208-3455`) carries this chip's addresses; the loader builds it from the platform table | to do |
| 2.3 | the virtual timer's number | `GIC_INTID_VTIMER` is 19 (Qualcomm's), not 27 (the architectural one), and the timer fires in QEMU | to do |
| 2.4 | the SPMI arbiter's addresses given at run time | `pmic_arb_core=`, `pmic_arb_cnfg=`, `pmic_arb_obsrvr=` (names to be chosen) reach the PMIC and the buttons drivers | to do |
| 2.5 | the thermal sensors | the sensors of this chip (one block at 0x10ad000) are read and their number is printed | to do |
| 2.6 | the modem's blocks | the glink transport is read where the driver expects the IPCC | to do |
| 2.7 | the clock of the cores | the driver reads this chip's RPM instead of a command database that does not exist here | to do |

**Nothing in this stage needs the phone.** Every step is checked in QEMU, where the log is the receipt.

## Stage 3 -- the firmware that starts the kernel

| # | Step | Done when | State |
|---|---|---|---|
| 3.1 | what starts the kernel on this phone | the chain is written down and each link is a file that exists: Qualcomm's bootloader (ABL) -> the boot shim -> the loader -> the kernel | to do |
| 3.2 | the boot shim | a shim that ABL accepts (the Linux `arm64` image header) and that puts the payload where the loader reads it, at an address that does not collide with the kernel's window | to do |
| 3.3 | the payload's address | the payload is not in the last 16 MB of this phone's RAM, or the loader's window leaves it alone (`docs/port-notes.md`, section 5) | to do |
| 3.4 | the UEFI | a firmware for this phone: its memory map, its device tree, its driver list; the vendor's own DXE drivers come off **your** phone and are not in the repository | to do |
| 3.5 | the framebuffer | the bootloader hands a framebuffer over, and the loader shows the logo and the log on it | to do |

## Stage 4 -- the first run on the phone

| # | Step | Done when | State |
|---|---|---|---|
| 4.1 | a way back | the stock images are on the computer, `fastboot` works, and the bootloader is in the state it was in before | to do |
| 4.2 | the first boot, from RAM | the phone is started with `fastboot boot` (nothing is written to the flash), the loader's banner appears, and the phone comes back to Android afterwards | to do |
| 4.3 | the log | the loader's log is on the computer, with the kernel's first lines in it | to do |
| 4.4 | the kernel's own window | the kernel owns a window that is free of the secure firmware's memory (0x85600000-0x95000000) | to do |

**The rules of this stage:** nothing is flashed; no partition is written; the bootloader is not touched; the phone goes back
to Android on its own.

## Stage 5 -- the drivers, one at a time

In the order the dependencies ask for (the reference port's order, `docs/porting/index.md`):

| # | Driver | Needs | Checked when |
|---|---|---|---|
| 5.1 | CPUFREQ | this chip's RPM (glink), not the command database | the cores' clock is read and the log says it |
| 5.2 | SOCINFO | the SMEM at 0x86000000 (in `soc.args` already) | the chip's identity is printed |
| 5.3 | THERMAL | one block at 0x10ad000 and this chip's sensor map | the readings are printed, and they move with the phone |
| 5.4 | PMIC | the arbiter's three blocks | the PMIC answers |
| 5.5 | BUTTONS | the PON inputs and the PM660L's GPIO 7 | the keys are seen |
| 5.6 | touch | a driver for the Synaptics TCM (or the Novatek NVT) on I2C1 | the screen answers |
| 5.7 | storage | a driver for the eMMC (SDHC1) | the phone's own partitions are read |
| 5.8 | ADRENO | a driver for the Adreno 512 (A5xx) | the GPU is woken and draws |
| 5.9 | ADSP, SOUND, MIC, SPEAKER | this phone's audio (the PMIC's codec and the SoundWire) | a tone comes out |
| 5.10 | BATTERY | the DSP | the level is read |
| 5.11 | WIFI | a driver for the WCN3990 | a network is joined |
| 5.12 | HAPTIC | the PM660's ERM driver | the motor turns |
| 5.13 | CAMERA, TORCH | this phone's three sensors and the PM660L's flash | a picture comes out |
| 5.14 | MODEM, QMI, CELL | the glink transport | the modem registers |

Each driver that is done is written down as a `status` line in `device.conf`, and only then.

## What is deliberately not in this plan

* **The GPU's Metal path.** It is written for one Adreno (0x06030500). The Adreno 512 is another generation.
* **The touch's Goodix path.** This phone has no Goodix.
* **Anything that writes to the phone.** The port runs from RAM.
* **Secure boot, verified boot, the trust cache.** Apple's are not Apple's to give, and Qualcomm's runtime services are not
  implemented in any of the UEFI trees that exist for this chip.
