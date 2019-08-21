using BinaryBuilder, Dates
include("../common.jl")

# Don't mount any shards that you don't need to
Core.eval(BinaryBuilder, :(bootstrap_mode = true))

compiler_target = platform_key(ARGS[end])
if typeof(compiler_target) <:UnknownPlatform
    error("This is not a typical build_tarballs.jl!  Must provide exactly one platform as the last argument!")
end

name = "PlatformSupport"
version = VersionNumber("$(year(today())).$(month(today())).$(day(today()))")

if isa(compiler_target, Linux)
    sources = Any[
        "https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.12.tar.xz" =>
        "a45c3becd4d08ce411c14628a949d08e2433d8cdeca92036c7013980e93858ab",
    ]
elseif isa(compiler_target, Windows)
    sources = Any[
        "https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v6.0.0.tar.bz2" =>
        "805e11101e26d7897fce7d49cbb140d7bac15f3e085a91e0001e80b2adaf48f0",
    ]
elseif isa(compiler_target, MacOS)
    sources = Any[
        "https://github.com/phracker/MacOSX-SDKs/releases/download/10.13/MacOSX10.10.sdk.tar.xz" =>
        "4a08de46b8e96f6db7ad3202054e28d7b3d60a3d38cd56e61f08fb4863c488ce",
    ]
elseif isa(compiler_target, FreeBSD)
    sources = Any[
        "https://download.freebsd.org/ftp/releases/amd64/11.2-RELEASE/base.txz" =>
        "a002be690462ad4f5f2ada6d01784836946894ed9449de6289b3e67d8496fd19",
    ]
else
    error("Unknown platform type $(compiler_target)")
end
push!(sources, "./bundled")

script = raw"""
## Function to take in a target such as `aarch64-linux-gnu`` and spit out a
## linux kernel arch like "arm64".
target_to_linux_arch()
{
    case "$1" in
        arm*)
            echo "arm"
            ;;
        aarch64*)
            echo "arm64"
            ;;
        powerpc*)
            echo "powerpc"
            ;;
        i686*)
            echo "x86"
            ;;
        x86*)
            echo "x86"
            ;;
    esac
}

## sysroot is where most of this stuff gets plopped
sysroot=${prefix}/${target}/sys-root

# Install kernel headers
case "${target}" in
    *-linux-*)
        cd $WORKSPACE/srcdir/linux-*/

        # Grumble, grumble, need gcc just to install some headers...
        apk add gcc musl-dev

        # The kernel make system can't deal with spaces (for things like ccache) very well
        KERNEL_FLAGS="ARCH=$(target_to_linux_arch ${target}) -j${nproc}"
        make ${KERNEL_FLAGS} mrproper V=1
        make ${KERNEL_FLAGS} headers_check V=1
        make ${KERNEL_FLAGS} INSTALL_HDR_PATH=${sysroot}/usr V=1 headers_install
        ;;

    *-mingw*)
        cd $WORKSPACE/srcdir/mingw-*/mingw-w64-headers
        ./configure --prefix=/ \
            --enable-sdk=all \
            --enable-secure-api \
            --host=${target}

        make install DESTDIR=${sysroot}
        ;;

    *-freebsd*)
        mkdir -p "${sysroot}/usr"
        mv usr/include "${sysroot}/"
        ln -sf "../include" "${sysroot}/usr/include"
        ;;

    *-apple-*)
        cd $WORKSPACE/srcdir/MacOSX10.10.sdk
        mkdir -p "${sysroot}/usr"
        mv usr/include "${sysroot}/usr"
        mv System "${sysroot}/"
        ;;
    *)
        echo "ERROR: Unmatched platform!" >&2
        exit 1
        ;;
esac

# Install cmake templates
cd ${WORKSPACE}/srcdir/cmake_toolchains
./build_toolchains.sh
mv ${target}/* ${prefix}

# We create a link from ${target}/sys-root/usr/local/lib to /workspace/destdir/lib
# This is the most reliable way for our sysroot'ed compilers to find destination
# libraries so far, hopefully this changes in the future.
mkdir -p ${sysroot}/usr/local
ln -sf /workspace/destdir/lib ${sysroot}/usr/local/lib
ln -sf /workspace/destdir/lib64 ${sysroot}/usr/local/lib64
"""

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, [triplet(compiler_target)], prefix -> Product[], []; skip_audit=true)

