using BinaryBuilder

# Collection of sources required to build Nettle
name = "libsnark"
version = v"2019.06.18"
sources = [
    "https://github.com/scipr-lab/libsnark.git" =>
    "477c9dfd07b280e42369f82f89c08416319e24ae",
    "https://github.com/scipr-lab/libfqfft.git" =>
    "e0183b2cef7d4c5deb21a6eaf3fe3b586d738fe0",
    "https://github.com/herumi/ate-pairing.git" =>
    "e69890125746cdaf25b5b51227d96678f76479fe",
    "https://github.com/google/googletest.git" =>
    "3a4cf1a02ef4adc28fccb7eef2b573b14cd59009",
    "https://github.com/scipr-lab/libff.git" =>
    "f2067162520f91438b44e71a2cab2362f1c3cab4",
    #"https://github.com/herumi/xbyak.git" =>
    #"f0a8f7faa27121f28186c2a7f4222a9fc66c283d",
    "https://github.com/mbbarbosa/libsnark-supercop.git" =>
    "b04a0ea2c7d7422d74a512ce848e762196f48149",
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/

# Link "submodules" in
for submodule in ate-pairing libff libfqfft libsnark-supercop; do
    rm -rf libsnark/depends/${submodule}
    ln -sf $(pwd)/${submodule} libsnark/depends/${submodule}
done
rm -rf libsnark/depends/gtest
ln -sf $(pwd)/googletest libsnark/depends/gtest

# ....recursively....
for submodule in ate-pairing libff; do
    rm -rf libfqfft/depends/${submodule}
    ln -sf $(pwd)/${submodule} libfqfft/depends/${submodule}
done
rm -rf libfqfft/depends/gtest
ln -sf $(pwd)/googletest libfqfft/depends/gtest

# We need the boost headers, so install them
apk update && apk add boost-dev

# For some reason, CMake isn't automatically including `${prefix}/include`....
export CFLAGS=-I${prefix}/include

mkdir build && cd build
cmake ../libsnark -DCMAKE_INSTALL_PREFIX=${prefix} \
      -DCMAKE_TOOLCHAIN_FILE=/opt/${target}/${target}.toolchain \
      -DMULTICORE=ON \
      -DCURVE=ALT_BN128 \
      -DWITH_PROCPS=OFF
make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# Disable FreeBSD for now, because hogweed needs alloca()?
#platforms = [p for p in platforms if !(typeof(p) <: FreeBSD)]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libsnark", :libsnark),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    "https://github.com/JuliaPackaging/Yggdrasil/releases/download/OpenSSL-v1.1.1%2Bc%2B0/build_OpenSSL.v1.1.1+c.jl",
    "https://github.com/JuliaMath/GMPBuilder/releases/download/v6.1.2-2/build_GMP.v6.1.2.jl",
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
