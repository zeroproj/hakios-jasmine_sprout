#!/usr/bin/env python3
"""Print the modem/IPA SoC addresses of the Xiaomi Mi A2 (jasmine_sprout) as HakiOS boot-args.

usage: tools/soc-args-caf.py DEVICE-TREE.dtb

Why this file exists
--------------------
The common repository's `tools/soc-args.py` reads a *mainline-style* device tree: it looks for
`qcom,cmd-db`, `qcom,ipcc`, `qcom,rpmh-rsc`, an `apps-smmu` node, an `ipa_gsi` reservation and a
`qcom,smem` node with a `memory-region` property.

The Mi A2 runs a **Qualcomm CAF** kernel (MiCode/Xiaomi_Kernel_OpenSource, branch `jasmine-q-oss`,
4.4.192). Its tree is CAF's, and it uses CAF's names:

  * the IPC to the modem is `qcom,glink-smem-native-xprt-modem`, not `qcom,ipcc`
  * the RPM's transport is `qcom,glink-rpm-native-xprt`, not `qcom,rpmh-rsc`
  * the shared memory is a plain `reg` on `qcom,smem`, with no `memory-region`
  * the modem's memory is the reserved-memory `modem_fw_mem`, not `mpss`
  * there is no AOSS mailbox, no command DB and no `ipa_gsi` reservation on this chip at all

So the common tool finds only the IPA and the IMEM here. This file reads the CAF names, prints the
same `soc_*` boot-args, and says which of them this chip does not have.

Everything it prints is read out of the tree: the numbers are not written here. Where a value has
no node in the tree, the argument is left out and named in the report at the end.
"""
import struct
import sys

# The node names of the CAF tree of this phone, and what each one is asked for.
# (compatible to look for, or the last component of the node's name; the argument it gives)
NODES = [
    # the IPA's registers are 0x40000 into the region the node describes, and the GSI is its second tuple
    (('compatible', 'qcom,ipa'), 'soc_ipa_base', 0, 0x40000),
    (('compatible', 'qcom,ipa'), 'soc_gsi_base', 1, 0),
    # the shared memory: a plain reg on qcom,smem in the CAF tree
    (('compatible', 'qcom,smem'), 'soc_smem', 0, 0),
    # the modem's own memory: the reserved-memory the CAF tree calls modem_fw_region
    (('leaf', 'modem_fw_region'), 'soc_mpss_mem', 0, 0),
    # the RPM's transport: the glink RPM xprt in the CAF tree
    (('compatible', 'qcom,glink-rpm-native-xprt'), 'soc_rsc', 0, 0),
    # the GPU's SMMU: the CAF tree calls it qcom,kgsl-iommu
    (('compatible', 'qcom,kgsl-smmu-v2'), 'soc_apps_smmu', 0, 0),
    # the IMEM, rounded down to its 2 MB block (what the IPA's table maps)
    (('compatible', 'qcom,msm-imem'), 'soc_imem', 0, 0),
]

# Arguments this chip has no node for. They are reported, not printed: a boot-arg that names an
# address the chip does not have is worse than no boot-arg at all.
ABSENT = {
    'soc_cmd_db': 'no command DB on this chip (the CAF tree of the Mi A2 has no cmd-db node)',
    'soc_ipcc': 'no IPCC on this chip: the IPC to the modem is the glink SMEM transport',
    'soc_aoss': 'no AOSS mailbox on this chip (SDM660 has no qcom,qmp-aop)',
    'modem_ipa_fw_at': 'no ipa_gsi reservation in the CAF tree; the modem firmware region is modem_fw_mem',
}


def nodes_of(blob):
    if blob[:4] != b'\xd0\x0d\xfe\xed':
        sys.exit('soc-args-caf.py: not a flattened device tree')
    off_struct, off_strings = struct.unpack('>II', blob[8:16])
    size_strings, = struct.unpack('>I', blob[32:36])
    strings = blob[off_strings:off_strings + size_strings]
    out, path, at = {}, [], off_struct
    while True:
        token, = struct.unpack('>I', blob[at:at + 4])
        at += 4
        if token == 1:                                  # FDT_BEGIN_NODE
            end = blob.index(b'\0', at)
            path.append(blob[at:end].decode())
            at = (end + 4) & ~3
            out['/'.join(path)] = {}
        elif token == 2:                                # FDT_END_NODE
            path.pop()
        elif token == 3:                                # FDT_PROP
            length, name_off = struct.unpack('>II', blob[at:at + 8])
            at += 8
            name = strings[name_off:strings.index(b'\0', name_off)].decode()
            out['/'.join(path)][name] = blob[at:at + length]
            at = (at + length + 3) & ~3
        elif token == 9:                                # FDT_END
            return out
        elif token != 4:                                # 4 = FDT_NOP
            sys.exit(f'soc-args-caf.py: unexpected token {token}')


def find(nodes, compatible):
    for path, props in nodes.items():
        if compatible.encode() in props.get('compatible', b'').split(b'\0'):
            return path, props
    return None, None


def find_leaf(nodes, leaf):
    for path, props in nodes.items():
        if path.rsplit('/', 1)[-1].split('@', 1)[0] == leaf:
            return path, props
    return None, None


def stream(nodes, compatible):
    """The IPA's stream number: the second cell of the iommus property (<phandle stream mask>)."""
    _, props = find(nodes, compatible)
    if props and 'iommus' in props and len(props['iommus']) >= 8:
        return u32(props['iommus'], 1)
    return None


def u32(value, index=0):
    return struct.unpack_from('>I', value, index * 4)[0]


def reg_address(nodes, path, index=0):
    """The address of the `index`-th reg tuple of a node, or None."""
    if path is None or 'reg' not in nodes[path]:
        return None
    parent = nodes[path.rsplit('/', 1)[0]]

    def width(name, default, allowed):
        value = parent.get(name, struct.pack('>I', default))
        if len(value) != 4 or u32(value) not in allowed:
            sys.exit(f'soc-args-caf.py: {path}: unsupported or malformed {name}')
        return u32(value)

    address_cells = width('#address-cells', 2, (1, 2))
    size_cells = width('#size-cells', 1, (0, 1, 2))
    stride = 4 * (address_cells + size_cells)
    data = nodes[path]['reg']
    if len(data) % stride:
        sys.exit(f'soc-args-caf.py: {path}: reg does not contain complete address/size tuples')
    at = index * stride
    if at >= len(data):
        return None
    return int.from_bytes(data[at:at + 4 * address_cells], 'big')


def main():
    sys.stdout.reconfigure(newline="\n")
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    nodes = nodes_of(open(sys.argv[1], 'rb').read())
    args = []

    for (kind, name), argument, index, offset in NODES:
        path, _ = find(nodes, name) if kind == 'compatible' else find_leaf(nodes, name)
        address = reg_address(nodes, path, index)
        if address is None:
            continue
        value = address + offset
        if argument == 'soc_imem':
            value &= ~0x1fffff                # the 2 MB block that holds the IMEM
        if not 0 <= value < 1 << 32:
            sys.exit(f'soc-args-caf.py: {argument}={value:#x} does not fit the kernel\'s 32-bit argument')
        args.append((argument, value))

    for argument, value in args:
        print(f'{argument}={value:#x}')

    for compatible, argument in (('qcom,ipa-smmu-ap-cb', 'soc_ipa_stream'),
                                 ('qcom,ipa-smmu-uc-cb', 'soc_ipa_stream_uc')):
        value = stream(nodes, compatible)
        if value is not None:
            print(f'{argument}={value:#x}')

    print('# not on this chip:', file=sys.stderr)
    for argument, why in sorted(ABSENT.items()):
        print(f'#   {argument}: {why}', file=sys.stderr)

    if not args:
        sys.exit('soc-args-caf.py: found none of the expected nodes; is this the phone\'s own device tree?')


if __name__ == '__main__':
    main()
