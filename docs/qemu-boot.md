# A boot of this port's configuration, in QEMU

The log of a run of the kernel this repository's configuration builds, in QEMU's `virt` machine. It is the receipt for what
the port does and does not yet do.

**What it is:** `qemu/run.sh` with a payload of `xnuloader/mkpayload.py` (the kernel built with this port's configuration,
the `hello` RAM disk, the command line of the configuration and of `soc.args`), on a machine with eight cores
(`QEMU_SMP=8`, because the configuration asks for eight).

**What it is not:** a run on the phone. QEMU's machine is not this phone's, and nothing here has been on the device.

## The run

```
== XNULOADER v3 ==
   kernel.ver=2.3.4-hakios-darwin22.5-sdm660-g63fc2b46-dirty
platform qemu-virt
payload entry 'kernel' size e2bb38
payload entry 'ramdisk' size 4090
payload entry 'cmdline' size ee
payload entry 'kernel.ver' size 2f
cmdline: 322 of 607 characters
cmdline: debug=0x8 serial=3 rd=md0 hakios_kver=2.3.4-hakios-darwin22.5-sdm660-g63fc2b46-dirty
         cpus=8 bootcpu=7 cpufreq=1 socinfo=1
         soc_ipa_base=0x147c0000 soc_gsi_base=0x14784000 soc_smem=0x86000000
         soc_mpss_mem=0x8ac00000 soc_rsc=0x778000 soc_apps_smmu=0x5040000
         soc_imem=0x14600000 soc_ipa_stream=0x19c0 soc_ipa_stream_uc=0x19c2
```

The kernel's version carries the SoC's name (`sdm660`), and the SoC's nine addresses are on the command line.

```
socinfo: item 137 is not in the shared memory at 0x86000000 (partition table magic 0, legacy version word 0)
socinfo: the legacy table has allocated: nothing; the partition table has 0 entries
hakios-kernel: 9 drivers built in (.config): virtio_sound socinfo virtio_input virtio_net cpufreq thermal pmic battguard virtio_blk
GenericARMPE: platform "device-tree"
cpufreq: group 0 (7 of our cores): row 4294967295 -> 0 of the frequency table, 4896 MHz
cpufreq: on core 0 a loop ran at 185, now at 182
Hello from user space on Darwin!
panic(cpu 0 caller 0xfffffff007786718): initproc failed to start -- no exit reason available -- (signal 0, exit status 0 )
```

**The shared memory is read at 0x86000000** -- this chip's address, from `soc.args` -- and not at the reference phone's
0x80900000. That is the port's own value reaching the kernel, and it is the first thing in this log that is *this phone's*.

The panic at the end is what the Apple-free path ends in: `launchd` cannot start without a Darwin user space. The reference
run ends the same way.

## What this log says about the work left

* **`hakios-kernel: 9 drivers built in`** -- nine of the common repository's twenty-five. The rest are the reference phone's
  hardware, and are left out of this configuration on purpose (`configs/jasmine_sprout.config`).
* **`thermal` is not on the command line of this run.** The configuration asks for it, and the thermal driver reads the
  reference phone's two blocks at 0xc263000 and 0xc265000, which QEMU's machine does not have: the run stops with a data
  abort right after "thermal: 27 sensors in two blocks". Until this chip's sensors are in that driver, the configuration
  cannot be run in QEMU as it is.
* **`cpufreq: ... row 4294967295 -> 0 of the frequency table`** -- the clock driver reads the command database the bootloader
  left, and this chip has none. The driver has to learn this chip's RPM.
* **`socinfo: ... magic 0`** -- QEMU has no shared memory. On the phone there is one, at 0x86000000.
