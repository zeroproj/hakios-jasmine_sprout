# The firmware that starts the kernel on this phone

Nothing here has been built or run. This file says what exists for this chip, what does not, and what the port has to make.

## The chain

```
Qualcomm's own bootloader (XBL -> TZ/RPM -> ABL)
    -> the boot shim          (an image ABL accepts; it puts the payload where the loader reads it)
        -> HakiOS's loader    (an EFI application; it builds the device tree and starts the kernel)
            -> the XNU kernel
```

Each link is a file that has to exist. On the reference phone (the POCO X5 Pro) the UEFI is a patch over
`Project-Silicium/Mu-Silicium`, and the shim is a small piece of assembly in front of it.

## What exists for this chip

| | | |
|---|---|---|
| `edk2-msm` (`Silicon/Qualcomm/sdm660/`) | a full SDM660 SoC layer: the memory map, the pre-PI library, the DSDT | the **SoC**, not this board |
| `edk2-msm-platina` | the Mi 8 Lite: the same chip, a different board | its author calls it "broken"; its CI builds only this device |
| `Mu-Silicium` | no SDM660 platform at all; its "Snapdragon 660" entry (lavender) is marked inactive | — |
| `hakios-uefi` | HakiOS's patch over Mu-Silicium, and the `XnuLoader` application | the shape this port follows |

## What is missing, and what it needs

* **A board.** No UEFI anywhere targets `jasmine_sprout`. A port of this chip is a port of a *board*: its device tree, its
  memory map, its driver list, its panel's geometry.
* **The vendor's own DXE drivers.** They are not in any repository: they are extracted from the phone's own UEFI volume
  (`xbl`), and they are that phone's. They are what drives the panel, the charger and the USB.
* **A Qualcomm runtime service.** None of the three UEFI trees for this chip has one: no SCM, no verified boot, no RPM
  attestation. A boot shim that only has to put a payload in memory and jump to it does not need one; anything more does.
* **The loader's place in the chain.** The reference port's loader is an EFI application that the UEFI starts. Here, with no
  UEFI for this board, the loader would have to be started by the shim directly -- which means the shim has to do what the
  loader's UEFI half does: find the memory map, find the framebuffer, and pass the environment over.

## The shape of the port's `uefi/` directory

Following the reference port (`hakios-sm7325/uefi/`):

```
uefi/files/Platforms/Xiaomi/jasmine_sproutPkg/    the memory map and the driver list
uefi/files/Resources/Configs/jasmine_sprout.toml   the device's configuration
uefi/files/Resources/DTBs/jasmine_sprout.dtb       the phone's own device tree
uefi/files/Binaries/jasmine_sprout/                the vendor's DXE drivers -- NOT tracked: they come off your phone
uefi/README.md                                      what is needed to build it, and what is not there yet
```

The memory map that goes in it is the one of `edk2-msm-platina`
(`Silicon/Qualcomm/sdm660/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c`), with this board's entries: the panel's
geometry, the RAM's size, and the addresses this board's own drivers use.

**What that map says about the RAM** (the same file, `:9-52`): the RAM starts at **0x80000000**; the secure firmware owns
0x85600000-0x95000000; the display's buffer is at 0x9d400000; the pool for the DXE heap is at 0xA0000000. Two of the map's
entries contradict each other (it names a "UEFI FD" both at 0x9FC00000 and at 0xCE000000, the latter overlapping the RAM
partition) and have to be settled before anything is built.
