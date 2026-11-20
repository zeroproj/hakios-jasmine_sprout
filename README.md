# Xiaomi Mi A2 (jasmine_sprout) -- a HakiOS/XNU port

An experimental port of the HakiOS kernel (Apple's open-source Darwin kernel, XNU 8796.121.2) to the Xiaomi Mi A2, which
runs a Qualcomm SDM660 (Snapdragon 660).

**Nothing here has been run on the phone.** The port is in its first stage: the phone's facts are read out of its own vendor
kernel, the SoC's configuration is written down, and the plan says what is to be done and how each step is checked. The
kernel itself builds on Linux and boots in QEMU; the phone is not touched.

## The state, part by part

| | |
|---|---|
| The phone's device tree | built from the phone's own vendor kernel (`MiCode/Xiaomi_Kernel_OpenSource`, `jasmine-q-oss`) and in `prebuilt/device-tree.dtb` |
| The SoC's configuration | `soc/configs/sdm660.config`; the phone's own in `configs/jasmine_sprout.config` |
| The SoC's addresses | `soc.args`, every one of them read out of the device tree |
| The hardware | `docs/port-notes.md`: every address, interrupt and GPIO, with the file and line it came from |
| The plan | `docs/plan.md`: the steps, and how each one is checked |
| What works on the phone | **nothing** (see `device.conf`) |

## The repository

```
device.conf            what this device is, and how far each part works
soc.args               the SoC's addresses, as the kernel's boot-arguments
configs/               this phone's kernel configuration
soc/                   the SDM660 family's facts, and the configuration they bring
prebuilt/device-tree.dtb   the phone's own device tree, built from its vendor kernel
docs/port-notes.md     the hardware, with its sources; what differs from the reference phone
docs/plan.md           the steps, and how each is checked
tools/soc-args-caf.py  reads this phone's device tree (a Qualcomm CAF one) into the SoC's addresses
pull-firmware.sh       the phone's firmware, off the phone over adb (never committed: it is the vendor's)
pull-soc.sh            the phone's live device tree, into soc.args
uefi/                  the firmware that starts the loader: what exists for this chip, and what is missing
```

## The facts that shape the port

The short version; `docs/port-notes.md` has each one with its source.

* **The GIC is v3 at 0x17a00000, and the redistributors start at 0x17b00000** -- one megabyte higher than the reference
  phone's. The loader's platform table has to say so.
* **Qualcomm numbers the EL1 virtual timer PPI 3, which is INTID 19.** The kernel's driver has 27, the architectural number.
  On this chip the timer must be 19 or the kernel stops at its first tick.
* **The storage is eMMC, not UFS.** The only storage driver is UFS.
* **The GPU is an Adreno 512 (A5xx), not the Adreno 642L (A6xx)** the GPU driver was written for.
* **The touch is a Synaptics TCM on I2C**, not a Goodix on SPI.
* **The keys are the PMIC's PON inputs**, not GPIOs, and the PMIC's arbiter is at 0x0800f000, not at the reference phone's
  0x0c440000.
* **The modem's IPC is the glink transport**: this chip has no IPCC, no AOSS mailbox and no command database.
* **The panel of the tree is 1080 x 2340**, and which panel this phone has must be read off the phone's own tree.
* **The payload goes to 0xF0000000**, which with 4 GB of RAM at 0x80000000 is the last 16 MB of the RAM -- inside the window
  the kernel is about to claim.

## Building and running it

The common repository is built and run the way its own documentation says; this repository holds the phone's part.

```sh
# in the common repository (hakios-xnu-kernel)
make jasmine_sprout_defconfig       # the phone's configuration
make config                         # what it holds, and what it needs
make kernel                         # the kernel
make loader                         # the boot loader
make qemu-open                      # the whole thing in QEMU, with nothing of Apple's
```

The phone's own firmware is needed before a run on the phone, and comes off the phone itself:

```sh
./pull-firmware.sh                  # the vendor's firmware into fw-*/ (never committed)
./pull-soc.sh                       # the phone's live device tree into soc.args
```

## The rules this port follows

* No address, interrupt or memory region is written here that was not read out of a source: the tree of the phone's own
  vendor kernel, the vendor's own firmware, or the sources of the kernel it is a port of.
* What is **written** is not what **works**. `device.conf` says what has been seen on the phone, and nothing has been.
* The phone is not written to. The port runs from RAM; a reboot gives the phone back to Android.
* Nothing of the vendor's is committed: the firmware comes off your own phone.
* The commits are small and reversible.
