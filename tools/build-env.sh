#!/bin/bash
# Set up a Linux machine to build the HakiOS kernel, **without root**.
#
#   . tools/build-env.sh [PREFIX]     (PREFIX: where the tools go; default /tmp/opencode/tc)
#
# The kernel's build needs, and nothing here is installed system-wide:
#
#   clang            the cross compiler (the wrapper xnu-deps/host/bin/xnu-clang drives it)
#   cctools          the Mach-O linker (ld) and its companions, from a Linux iOS toolchain
#   iPhoneOS16.5.sdk  the SDK the kernel is compiled against, from github.com/theos/sdks
#   flex, bison, m4, autoconf, automake, m4sugar   the host tools the kernel's own build uses
#   mig, tcsh, unifdef   the host tools XNU's build needs (Apple's mig is closed; a port builds)
#   QEMU and AArch64 firmware   to run the result
#
# What the upstream instructions say is needed is in xnu-deps/setup.sh; this script puts it where a machine
# without root can use it. Nothing of it is committed to any repository.
#
# The one change to the common repository this needs is in xnu-deps/host/bin/xnu-clang: the wrapper names
# /usr/bin/clang outright, and a machine that installs clang without root has no clang there. The change
# makes the wrapper take the compiler from the PATH when /usr/bin has none, and leaves it alone when it
# does. It is one commit in the common repository, and it touches nothing else.
set -e
PREFIX=${1:-/tmp/opencode/tc}
mkdir -p "$PREFIX/tools" "$PREFIX/theos" "$PREFIX/work"
cd "$PREFIX"

# ---- the packages that could not be installed system-wide -----------------------------------------
# (name of the Debian package; the ones that were already there are skipped)
for p in flex bison m4 autoconf automake autoconf-archive gettext libtool-bin uuid-dev \
         libtinfo5 libfdt1 libpmem1 libslirp0 liburing2 libjpeg8 libfuse3-3 librdmacm1t64 \
         libpng16-16t64 libnuma1 libbpf1 libibverbs1 libndctl6 libdaxctl1 ipxe-qemu \
         device-tree-compiler qemu-system-arm qemu-system-common qemu-system-data qemu-efi-aarch64 ovmf; do
	apt-get download "$p" >/dev/null 2>&1 || { echo "build-env: could not get $p"; continue; }
	dpkg-deb -x "$(ls -t ${p}_*.deb 2>/dev/null | head -1)" "$PREFIX/tools" 2>/dev/null || true
done
# the .deb files put their tools in tools/usr/bin and tools/usr/lib; the .so files in tools/lib
ln -sf "$PREFIX/tools/usr/bin/automake-1.16" "$PREFIX/tools/usr/bin/automake" 2>/dev/null || true
ln -sf "$PREFIX/tools/usr/bin/aclocal-1.16" "$PREFIX/tools/usr/bin/aclocal" 2>/dev/null || true
ln -sf "$(command -v python3)" "$PREFIX/tools/usr/bin/python" 2>/dev/null || true

# ---- QEMU and its firmware ---------------------------------------------------------------------------
export LD_LIBRARY_PATH="$PREFIX/tools/lib/x86_64-linux-gnu:$PREFIX/tools/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
# the option ROMs, which QEMU looks for in its data directory
cp -rn "$PREFIX/tools/usr/lib/ipxe/qemu/." "$PREFIX/tools/usr/share/qemu/" 2>/dev/null || true

# ---- clang -------------------------------------------------------------------------------------------
# the official LLVM release: self-contained, and the version the kernel's build wants
LLVM_VER=18.1.8
if [ ! -d "$PREFIX/clang+llvm-$LLVM_VER-x86_64-linux-gnu-ubuntu-18.04" ]; then
	curl -L -o "$PREFIX/llvm.tar.xz" \
		"https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VER/clang+llvm-$LLVM_VER-x86_64-linux-gnu-ubuntu-18.04.tar.xz"
	tar xf "$PREFIX/llvm.tar.xz" -C "$PREFIX"
fi
# the headers XNU's host tools need (uuid/uuid.h), which the resource directory of clang does have
mkdir -p "$PREFIX/clang+llvm-$LLVM_VER-x86_64-linux-gnu-ubuntu-18.04/lib/clang/18/include"
cp -rn "$PREFIX/tools/usr/include/uuid" "$PREFIX/clang+llvm-$LLVM_VER-x86_64-linux-gnu-ubuntu-18.04/lib/clang/18/include/" 2>/dev/null || true

# ---- cctools and the SDK -----------------------------------------------------------------------------
if [ ! -x "$PREFIX/theos/toolchain/linux/iphone/bin/ld" ]; then
	curl -L -o "$PREFIX/iOSToolchain.tar.xz" \
		"https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz"
	mkdir -p "$PREFIX/theos/toolchain" && tar xJf "$PREFIX/iOSToolchain.tar.xz" -C "$PREFIX/theos/toolchain/"
fi
if [ ! -d "$PREFIX/theos-sdks/iPhoneOS16.5.sdk" ]; then
	git clone -q --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git "$PREFIX/theos-sdks"
	git -C "$PREFIX/theos-sdks" sparse-checkout set iPhoneOS16.5.sdk
fi
mkdir -p "$PREFIX/theos/sdks"
ln -sfn "$PREFIX/theos-sdks/iPhoneOS16.5.sdk" "$PREFIX/theos/sdks/iPhoneOS16.5.sdk"

# ---- the environment the kernel's build reads -------------------------------------------------------
cat > "$PREFIX/env.sh" <<EOF
export TC_ROOT=$PREFIX
export QEMU_PREFIX=\$TC_ROOT/tools
export LLVM_PREFIX=\$TC_ROOT/clang+llvm-$LLVM_VER-x86_64-linux-gnu-ubuntu-18.04
export THEOS=\$TC_ROOT/theos
export PATH=\$TC_ROOT/tools/usr/bin:\$LLVM_PREFIX/bin:\$QEMU_PREFIX/usr/bin:\$PATH
export LD_LIBRARY_PATH=\$LLVM_PREFIX/lib:\$TC_ROOT/tools/lib/x86_64-linux-gnu:\$TC_ROOT/tools/usr/lib/x86_64-linux-gnu:\$LD_LIBRARY_PATH
export AUTOMAKE_LIBDIR=\$TC_ROOT/tools/usr/share/automake-1.16
export AUTOM4TE=\$TC_ROOT/tools/usr/bin/autom4te
export AUTOM4TE_CFG=\$TC_ROOT/tools/usr/share/autoconf/autom4te.cfg
export autom4te_perllibdir=\$TC_ROOT/tools/usr/share/autoconf
export autom4te_buildauxdir=\$TC_ROOT/tools/usr/share/autoconf/build-aux
export AUTOCONF=\$TC_ROOT/tools/usr/bin/autoconf
export AUTOHEADER=\$TC_ROOT/tools/usr/bin/autoheader
export ACLOCAL_PATH=\$TC_ROOT/tools/usr/share/aclocal-1.16
export BISON_PKGDATADIR=\$TC_ROOT/tools/usr/share/bison
export M4=\$TC_ROOT/tools/usr/bin/m4
export PERL5LIB=\$TC_ROOT/tools/usr/share/autoconf:\$TC_ROOT/tools/usr/share/automake-1.16:\$PERL5LIB
export CPPFLAGS="-I\$TC_ROOT/tools/usr/include \$CPPFLAGS"
export LDFLAGS="-L\$TC_ROOT/tools/usr/lib/x86_64-linux-gnu \$LDFLAGS"
export QEMU_EFI=\$QEMU_PREFIX/usr/share/AAVMF/AAVMF_CODE.fd
export QEMU_VARS=\$QEMU_PREFIX/usr/share/AAVMF/AAVMF_VARS.fd
export QEMU_DATA=\$QEMU_PREFIX/usr/share/qemu
export LC_ALL=C
EOF

# ---- the autotools, which look for their data in /usr -----------------------------------------------
# the Debian scripts have /usr/share and /usr/bin baked in; point them at the local copy
for f in autoconf autoheader autoscan autoupdate aclocal-1.16 automake-1.16 autoreconf; do
	[ -f "$PREFIX/tools/usr/bin/$f" ] || continue
	sed -i -e "s|/usr/share/autoconf|$PREFIX/tools/usr/share/autoconf|g" \
	       -e "s|/usr/share/automake-1.16|$PREFIX/tools/usr/share/automake-1.16|g" \
	       -e "s|/usr/share/aclocal-1.16|$PREFIX/tools/usr/share/aclocal-1.16|g" \
	       -e "s|/usr/share/aclocal|$PREFIX/tools/usr/share/aclocal|g" \
	       -e "s|/usr/bin/autoconf|$PREFIX/tools/usr/bin/autoconf|g" \
	       -e "s|/usr/bin/autoheader|$PREFIX/tools/usr/bin/autoheader|g" \
	       -e "s|/usr/bin/autom4te|$PREFIX/tools/usr/bin/autom4te|g" \
	       -e "s|/usr/bin/m4|$PREFIX/tools/usr/bin/m4|g" \
	       "$PREFIX/tools/usr/bin/$f"
done
sed -i "s|/usr/share/autoconf|$PREFIX/tools/usr/share/autoconf|g" "$PREFIX/tools/usr/share/autoconf/autom4te.cfg"
sed -i "s|/usr/share/automake-1.16|$PREFIX/tools/usr/share/automake-1.16|g" "$PREFIX/tools/usr/share/automake-1.16/Automake/Config.pm"
# aclocal treats a missing system macro directory as fatal; a warning is enough
sed -i -e 's|scan_m4_dirs (FT_AUTOMAKE, SCAN_M4_DIRS_ERROR, @automake_includes);|scan_m4_dirs (FT_AUTOMAKE, SCAN_M4_DIRS_WARN, @automake_includes);|' \
       -e 's|scan_m4_dirs (FT_SYSTEM, SCAN_M4_DIRS_ERROR, @system_includes);|scan_m4_dirs (FT_SYSTEM, SCAN_M4_DIRS_WARN, @system_includes);|' \
       "$PREFIX/tools/usr/bin/aclocal-1.16"
# the automake's own config.guess/config.sub are links to a package that is not here
cp -f "$PREFIX/tools/usr/share/autoconf/build-aux/config.guess" "$PREFIX/tools/usr/share/automake-1.16/" 2>/dev/null || true
cp -f "$PREFIX/tools/usr/share/autoconf/build-aux/config.sub" "$PREFIX/tools/usr/share/automake-1.16/" 2>/dev/null || true

cat <<EOF

build-env: the tools are in $PREFIX.  Use them with:

    . $PREFIX/env.sh
    cd <the common repository>
    xnu-deps/setup.sh --stage1
    xnu-deps/setup.sh --stage2
    tools/make-kernel.sh -j8

build-env: the wrapper xnu-deps/host/bin/xnu-clang names /usr/bin/clang outright; a machine without root
build-env: has no clang there.  Give it one from the PATH (or name it in HAKIOS_CLANG); the change is one
build-env: commit in the common repository and touches nothing else.
EOF
