# Port notes: the Xiaomi Mi A2 (jasmine_sprout) on the HakiOS/XNU kernel

Every number here was read out of a source tree, and the place is named. Nothing here is a guess and nothing here has been
seen on the phone yet: the port has not been run on the device. What *has* been done is written in the "verified" column of
the last table.

## 1. The phone

| | | Source |
|---|---|---|
| Model | Xiaomi Mi A2 | `LineageOS/android_device_xiaomi_jasmine_sprout/lineage_jasmine_sprout.mk:23-26` (`PRODUCT_MODEL := Mi A2`, `PRODUCT_DEVICE := jasmine_sprout`) |
| Board | `jasmine_sprout` | the same |
| SoC | Qualcomm SDM660, `qcom,msm-id = <317>` (317 = 0x13D) | `MiCode/Xiaomi_Kernel_OpenSource` `jasmine-q-oss`, `arch/arm/boot/dts/qcom/sdm660_f7a.dtsi:27` |
| CPU | 8 Cortex-A53 (Kryo 260): 4 little at up to 1.633 GHz, 4 big at up to 2.4576 GHz | `sdm660_f7a.dtsi:50-242` (efficiency 1024 / 1638), cpufreq tables at `:1406-1424` |
| GPU | Adreno 512, `qcom,chipid = <0x05010200>` | `sdm660-gpu.dtsi:68`; the chip's name in the Linux source: `drivers/gpu/msm/adreno-gpulist.h:286-301` (`ADRENO_REV_A512`, `a530_pm4.fw`, `a530_pfp.fw`, `a512_zap`) |
| RAM | 4 GB, base **0x80000000** | the RAM base is **not in the device tree** (the `/memory` node is the empty placeholder the bootloader fills, `arch/arm/boot/dts/qcom/skeleton64.dtsi:14`); the base comes from the bootloader: `edk2-msm-platina/Silicon/Qualcomm/sdm660/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c:9` and `Platform/Qualcomm/sdm660/sdm660.dsc:26-27` |
| Display | 1080 x 2340, 60 Hz, 24 bpp, BOE TD4320 in video mode | `dsi-panel-boe-td4320-1080p-video.dtsi:16,19,22-23,37`; chosen by `sdm660-mtp_f7a.dtsi:108` |
| Storage | eMMC 5.1 (SDHC1 at 0x0c0c4000, 8-bit, HS400) | `sdm660-common_f7a.dtsi:551-559,612-617`; `sdm660-mtp_f7a.dtsi:230-254` |
| Touch | Synaptics TCM (I2C1, 0x20) or Novatek NVT (I2C1, 0x62) | `sdm660-synaptics-tcm-i2c_f7a.dtsi:35-57`, `sdm660-novatek-i2c_f7a.dtsi:37-47` |
| Modem | QDSP6 (MSS) at 0x4080000, PIL image, `qcom,pil-q6v55-mss` | `sdm660_f7a.dtsi:2086-2115` |
| Wi-Fi / BT | Qualcomm WCN3990, firmware at 0x18800000 | `sdm660_f7a.dtsi:431-448,1985-2018` |

**The "1080 x 2160" of the LineageOS device's README is not what this kernel's tree says.** The preferred panel of the tree
this port reads is 1080 x 2340 (`dsi-panel-boe-td4320-1080p-video.dtsi:22-23`). Panels of 2160 rows exist in the same tree
(they are the other SKUs of the family) but none of them is the preferred one, and there is no runtime panel-selection GPIO:
`qcom,dsi-pref-prim-pan` is the only selector (`sdm660-mtp_f7a.dtsi:108`). **Which panel this particular phone has must be read
off the phone's own live device tree before the framebuffer's geometry is written down.**

## 2. What this chip has, and where it is

| Block | Address | IRQ | Source |
|---|---|---|---|
| GICD (GICv3) | 0x17a00000, 0x10000 | — | `sdm660_f7a.dtsi:459-460` |
| GICR (8 redistributors, stride 0x20000) | 0x17b00000, 0x100000 | — | `sdm660_f7a.dtsi:460,466-467` |
| GIC's own interrupt | — | PPI 9 | `sdm660_f7a.dtsi:468` |
| SPMI arbiter (core / cnfg / chnls / obsrvr / intr) | 0x0800f000 / 0x0800a000 / 0x08400000 / 0x09400000 / 0x0a400000 | 326 | `sdm660_f7a.dtsi:505-514` |
| PM660 / PM660L (USIDs 0, 1, 2, 3) | SPMI | — | `msm-pm660_f7a.dtsi:18-20,666-668`, `msm-pm660l.dtsi:19-21,133-135` |
| PM660's PON (power key, volume down) | SPMI 0x800 | SPMI 0x8 | `msm-pm660_f7a.dtsi:36-74` |
| PM660L GPIO 7 (volume up) | SPMI 0xc600 | — | `sdm660_f7a.dtsi:2698-2705` |
| PM660's haptic (ERM) | SPMI 0xc000 (USID 1) | SPMI 0xc0 | `msm-pm660_f7a.dtsi:666-695` |
| TSENS0 | 0x10ad000, 0x2000 | 184 | `sdm660_f7a.dtsi:670-671` |
| eMMC (SDHC1) | 0x0c0c4000 (+ cmdq 0x0c0c5000) | 110, 112 | `sdm660-common_f7a.dtsi:551-557` |
| SD card (SDHC2) | 0x0c084000 | 125, 221 | `sdm660-common_f7a.dtsi:622-628` |
| USB3 (SuperSpeed) | 0x0a800000 | 347, 243, 180; dwc3 131; BAM 132 | `sdm660-common_f7a.dtsi:145-266` |
| USB2 HS | 0x0c200000 (disabled on this board) | 348, 144 | `sdm660-common_f7a.dtsi:465-511` |
| MDSS (display) | 0x0c900000 | 83 | `sdm660-mdss.dtsi:16-22` |
| DSI0 / DSI1 | 0x0c994000 / 0x0c996000 | — | `sdm660-mdss.dtsi:363-370,414-421` |
| GPU (KGSL) | 0x05000000, 0x40000 | 300 | `sdm660-gpu.dtsi:57-64` |
| GPU's SMMU | 0x05040000 | 229 | `sdm660-gpu.dtsi:677`, `msm-arm-smmu-660.dtsi:64-70` |
| CCI (cameras) | 0x0ca0c000 | 295 | `sdm660-camera.dtsi:677-686` |
| IPA (registers / GSI) | 0x14780000 (+0x40000) / 0x14784000 | 333, 432 | `sdm660_f7a.dtsi:1537-1543` |
| IPA's version | **IPAv2.6L**, `qcom,ipa-hw-ver = <6>` | — | `sdm660_f7a.dtsi:1537-1539` |
| SMEM | 0x86000000, 0x200000 | — | `sdm660_f7a.dtsi:1618-1627` |
| glink SMEM transport (modem) | 0x86000000 | 452 | `sdm660_f7a.dtsi:1736-1744` |
| glink SMEM transport (adsp) | 0x86000000 | 157 | `sdm660_f7a.dtsi:1746-1756` |
| glink SMEM transport (cdsp) | 0x86000000 | 513 | `sdm660_f7a.dtsi:1768-1776` |
| glink RPM transport | 0x778000, 0x7000 | 168 | `sdm660_f7a.dtsi:1778-1786` |
| Modem PIL (MSS) | 0x4080000 | 448 | `sdm660_f7a.dtsi:2086-2115` |
| aDSP PIL (LPASS) | 0x15700000 | 162 | `sdm660_f7a.dtsi:2020-2051` |
| CDSP PIL (Turing) | 0x1a300000 | 518 | `sdm660_f7a.dtsi:2053-2084` |
| RPM (code RAM / msg RAM / mailbox) | 0x778000 / 0x200000 / 0x7781b8 | 171 | `sdm660-pm.dtsi:316-336` |
| GCC (global clocks) | 0x100000, 0x94000 | — | `sdm660_f7a.dtsi:1072-1073` |
| APCS / OSM (core clocks) | 0x179c0000 | 35, 36 | `sdm660_f7a.dtsi:1278-1287` |
| Console UART (BLSP1 UART2) | 0x0c170000 | 108 | `sdm660_f7a.dtsi:684-692` |
| I2C1 (the touch's bus) | 0x0c175000 | 95 | `sdm660-blsp.dtsi:39-46` |
| I2C6 (the amplifiers' and NFC's bus) | 0x0c1b6000 | 102 | `sdm660-blsp.dtsi:169-176` |
| TLMM (GPIO) | 0x03000000, 0xc00000 | 208 | `sdm660-pinctrl.dtsi:15-16` |
| XO / sleep clock | 19.2 MHz / 32768 Hz | — | `sdm660_f7a.dtsi:287,294` |

### Memory the secure firmware owns (not the kernel's)

`0x85600000`–`0x95000000` in one block: the WLAN's MSA memory (0x85700000), the modem's firmware (0x8ac00000, 0x7e00000),
the aDSP's (0x92a00000, 0x1e00000), the modem's MBA (0x94800000) and the CDSP's (0x94a00000).
(`sdm660_f7a.dtsi:328-368`)

## 3. What this chip does NOT have, and what the tree says anyway

* **UFS.** The tree enables it (`sdm660-mtp_f7a.dtsi:40,53` turn the "disabled" of `sdm660_f7a.dtsi:2368,2436` back on), but
  **the Mi A2 has no UFS**: its storage is eMMC. The UFS node at 0x1da4000 must be treated as absent.
* **PCIe.** No node in any of the thirteen board files of this chip.
* **AOSS mailbox, an IPCC and a command DB.** None of the three is in the tree: this chip is old enough to use the glink
  transports, and it has no AOSS.
* **An IR blaster.** No node.

## 4. What differs from the reference phone (the POCO X5 Pro, SC7280), driver by driver

The kernel's drivers carry the reference phone's addresses as compiled-in defaults. Those that differ here are listed with
what this chip has instead. Each is a piece of work, not a number to change.

| Driver | The reference phone | This chip | How the value can be given |
|---|---|---|---|
| `hakios.mpss.c` (modem) | SMEM 0x80900000, the modem's memory 0x8b800000 (246 MB), the RSC mailbox 0x18220000, the IPCC 0x00408000, the AOSS mailbox 0x0c300000, the command DB 0x80860000 | SMEM 0x86000000, the modem's memory 0x8ac00000 (126 MB), the RPM's glink transport 0x778000, **no IPCC**, **no AOSS**, **no command DB** | the first two are in `soc.args`; **the transport is a different kind of block** (the driver's `rsc` block is 0x10000 bytes and is read as an RSC mailbox), and the IPCC and the AOSS have no counterpart |
| `hakios.ipa.c` | registers 0x01e40000, GSI 0x01e04000 | registers 0x147c0000, GSI 0x14784000, **IPAv2.6L** (the reference phone's is another version) | in `soc.args`; the version is the IPA driver's own business |
| `hakios.socinfo.c` | SMEM 0x80900000 | SMEM 0x86000000 | in `soc.args` |
| `hakios.pmic.c` | the arbiter's core 0x0c440000, cnfg 0x0c40a000, observer 0x0e600000 | core 0x0800f000, cnfg 0x0800a000, observer 0x09400000 | **no way to give it at run time**: a new boot-arg, or the driver's own copy in this device's repository |
| `hakios.buttons.c` | the same three arbiter addresses; the keys on GPIOs | the same three arbiter addresses; the keys are the PMIC's PON inputs (power, volume down) and the PM660L's GPIO 7 (volume up) | as above: a new boot-arg or a device's own driver |
| `hakios.thermal.c` | two blocks at 0xc263000 and 0xc265000, a table of 27 sensors | **one** block at 0x10ad000 (`qcom,sdm660-tsens`), the sensor map of the MSM8998 family | `thermal_tm0`/`thermal_tm1` exist, but the driver's table of 27 sensors and its register layout are the reference phone's |
| `hakios.adreno.c` | Adreno 642L (A6xx, chip id 0x06030500) | Adreno 512 (A5xx, chip id 0x05010200) | none: a different GPU generation, another driver |
| `hakios.ufshc.c` | UFS at 0x1d84000 | **no UFS**; eMMC at 0x0c0c4000 | none: a different controller, another driver |
| `hakios.goodix.c` | a Goodix or a FocalTech on SPI | a Synaptics TCM or a Novatek NVT on I2C1 | none: another bus, another driver |
| `hakios.haptic.c` | an Awinic AW86927 on I2C | the PM660's own ERM driver (USID 1, SPMI 0xc000) | none: the motor is in the PMIC |
| `hakios.adsp.c` | the aDSP of the SC7280 | the aDSP of this chip (LPASS at 0x15700000, image "adsp") | the same shape, another chip's firmware |
| `hakios.qmi.c` | the IPCC | the glink SMEM transport | none: another transport |
| `hakios.cpufreq.c` | the SC7280's command database | this chip's RPM (glink) | the driver reads the command DB the bootloader left; this chip has none |
| `hakios.wifi.c` | a WCN6750 with Linux's ath11k | a WCN3990 | none: another radio, another driver |

### The interrupt controller's numbering

`xnu/files/osfmk/arm64/gic_v3_irq.c:75` has `GIC_INTID_VTIMER 27`, the **architectural** number of the EL1 virtual timer.
Qualcomm numbers the architected timers differently: the EL1 virtual timer is PPI 3, which is **INTID 19**. The reference
phone happens to work with 27 (or the path is untested there); on this chip it must be 19, or the timer never fires and the
kernel stops at its first tick. The `ios-sweet` port has the same fix and reads the number out of the device tree at run time
(`xnu/patches/0017-sweet-device-tree-virtual-timer-irq.patch:104-121`).

### The loader's platform table

`xnuloader/loader.c:553-589` holds one `struct platform` per phone. The reference phone's is:

```
.name = "redwood", .io_base = 0x00400000, .io_size = 0x3FC00000,
.gic_dist = 0x17A00000, .gic_redist = 0x17A60000, .uart = 0,
.cores = 8, .core_shift = 8, .small_cores = 0x0f,
```

This chip's entries, from the tree above: **`gic_redist` is 0x17B00000**, not 0x17A60000 (the redistributors start one
megabyte higher on this chip: `sdm660_f7a.dtsi:460`). `io_base`/`io_size` are the window the device tree's peripherals live
in. `core_shift = 8` and `small_cores = 0x0f` hold here too: the tree numbers the cores 0-3 and 0x100-0x103
(`sdm660_f7a.dtsi:50-242`), and the four little ones are the slow ones.

## 5. The loader's memory window, and where the payload goes

The loader does **not** hardcode where the RAM is: it asks the firmware for the memory map and takes the largest free block
(`xnuloader/loader.c:2760-2816`), and it claims that window with `allocate_pages`. Two things follow for this phone:

1. The **payload** is placed by the boot shim at `PAYLOAD_BASE = 0xF0000000` (`loader.c:18`), and the loader reads it there
   (`loader.c:2598`). With 4 GB of RAM at 0x80000000, the top of the RAM is 0x100000000, so **0xF0000000 is the last 16 MB of
   this phone's RAM** -- inside the very window the kernel is about to claim. On the reference phone (12 GB) it is far above
   the RAM, so the two do not overlap. This has to be solved before a run on the phone: either the shim places the payload
   elsewhere, or the loader's window excludes the top of the RAM.
2. The window the loader picks must **not** cover the block the secure firmware owns (0x85600000-0x95000000, section 2). The
   firmware's memory map (`PlatformMemoryMapLib.c`) already reserves it, so a correct firmware keeps the loader out of it; a
   firmware that does not would have the kernel write over the modem's memory.

## 6. The state of the UEFI for this chip

* **There is no UEFI for the Mi A2.** No project anywhere targets `jasmine_sprout` (checked: `edk2-msm`, `edk2-msm-platina`,
  `Mu-Silicium`, `hiratazx-playground`).
* **`edk2-msm` has an SDM660 SoC layer** (`Silicon/Qualcomm/sdm660/`) and nine devices of that family (`clover`, `h7000`,
  `jason`, `nitrogen`, `r11`, `r11s`, `wayne`, `whyred`, `x00td`) -- **but no jasmine_sprout**, and its CI builds none of them.
* **`edk2-msm-platina` is the Mi 8 Lite**: the same chip, a different board. Its own author calls it "broken". It has a real
  `BdsDxe`, a GOP (`SimpleFbDxe` over the MIPI framebuffer at 0x9d400000) and the vendor's own DXE drivers, but **no Qualcomm
  runtime services at all** (no SCM, no verified boot, no persistent NVRAM) and a memory map whose two "UEFI FD" entries
  contradict each other.
* **The same board, a different product** is the blocker: the DTB (a vendor MTP tree with this board's regulators and panel),
  the vendor's DXE drivers (which are the Mi 8 Lite's own), the framebuffer's geometry (1080x2280 there, not this phone's) and
  the identity PCDs.
* **HakiOS's own firmware** is a patch over `Project-Silicium/Mu-Silicium` (`hakios-uefi`), and a device's platform lives in
  the device's own repository (`uefi/files/Platforms/Xiaomi/<device>Pkg`, the memory map and the driver list, the device's own
  DTB, the vendor's DXE binaries -- which are **not** in the repository: they come off your own phone). That is the shape this
  port's `uefi/` directory has to take.

## 7. What has been verified, and how

| Claim | How | State |
|---|---|---|
| The common repository builds on Linux | `tools/make-kernel.sh -j8` in a tree with the dependencies of `xnu-deps/setup.sh` | **done**: the kernel is built and linked; only the kext symbol-set checks fail, which that script documents as the expected outcome |
| The loader, the `hello` RAM disk and the kernel run in QEMU | `qemu/run.sh` with the payload of `xnuloader/mkpayload.py` | **done**: the loader's banner, the kernel's first lines, "25 drivers built in", "Hello from user space on Darwin!", then the panic of `launchd` that the Apple-free path ends in |
| This port's configuration is accepted by the project's own tools | `tools/hakios-device.py check jasmine_sprout` and `tools/hakios-config.py check` | **done**: "1 repositories checked (jasmine_sprout), all hold together"; 33 symbols, 46 characters of boot-arguments |
| The kernel builds **with this port's configuration** | `make jasmine_sprout_defconfig` then `tools/make-kernel.sh -j8` | **done**: no compile error; the version string carries the SoC's name (`2.3.4-hakios-darwin22.5-sdm660-...`) |
| The kernel built with this configuration runs in QEMU | `qemu/run.sh` with `cpus=8 bootcpu=7 cpufreq=1 socinfo=1` and `soc.args` | **done**: "hakios-kernel: 9 drivers built in (.config)" and "Hello from user space on Darwin!" |
| `soc.args` reaches the kernel | the same run | **done**: the log says "socinfo: item 137 is not in the shared memory at **0x86000000**" -- this chip's address, not the reference phone's 0x80900000 |
| This phone's device tree is readable and its addresses are what this port says | the tree of `MiCode/Xiaomi_Kernel_OpenSource` `jasmine-q-oss`, compiled to a DTB with the kernel's own `dtc` rules | **done**: `prebuilt/device-tree.dtb` is that tree; every address in sections 2 and 3 was read out of it |
| `soc.args` is what this phone needs | `tools/soc-args-caf.py` on that DTB | **done**: the nine values, each read out of the tree |
| The tree's `/memory` node | the tree | **empty**: the bootloader fills it; the RAM base comes from the firmware |
| Anything on the phone | — | **nothing**: no run on the device has happened |

### The two runs of QEMU, and what they say about the port

The port's configuration asks for **eight cores** (`cpus=8 bootcpu=7`), so the QEMU machine has to have eight:
`QEMU_SMP=8 ./qemu/run.sh`. With one core the run stops at "core 7 did not start: PSCI error 2" -- which is QEMU's
machine, not the port.

The configuration also asks for the temperature sensors (`thermal=1`), and the thermal driver reads the **reference phone's**
two blocks at 0xc263000 and 0xc265000, which QEMU's machine does not have: the run stops with a data abort right after
"thermal: 27 sensors in two blocks (0xc263000, 0xc265000)". The driver's own header says exactly this ("Not run in QEMU,
and thermal=1 must not be given there: it has no such blocks, and a load from an address it does not map faults"), and it is
the clearest measure of how much of the reference phone is still in the drivers: **until the sensors of this chip are in the
driver, the configuration cannot be run in QEMU as it is.** The run above therefore leaves `thermal` out, and the
configuration on the phone keeps it.

Two more things the QEMU log says about the port:

* `cpufreq: group 0 (7 of our cores): row 4294967295 -> 0 of the frequency table, 4896 MHz` -- the clock driver reads the
  command database the bootloader left, and **this chip has none**. The driver has to learn this chip's RPM.
* `socinfo: ... (partition table magic 0, legacy version word 0)` -- QEMU has no SMEM, so of course. On the phone the
  shared memory at 0x86000000 is the real one.

