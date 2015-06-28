#!/bin/bash

set -e
set -o pipefail
set -x


function install_packages() {
    cd /root

    apt-key add - <  /root/llvm-snapshot.gpg.key
    tee /etc/apt/sources.list.d/llvm.list <<EOF
deb http://llvm.org/apt/jessie/ llvm-toolchain-jessie-3.6 main
deb-src http://llvm.org/apt/jessie/ llvm-toolchain-jessie-3.6 main
EOF

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qyy
    DEBIAN_FRONTEND=noninteractive apt-get install -qyy \
        automake            \
        bison               \
        build-essential     \
        clang-3.6           \
        cmake               \
        curl                \
        file                \
        flex                \
        git                 \
        ninja-build         \
        pkg-config          \
        python              \
        subversion          \
        texinfo             \
        vim                 \
        wget

    # Use clang-3.6 as default clang + tools
    update-alternatives \
        --install /usr/bin/clang        clang        /usr/bin/clang-3.6     50      \
        --slave   /usr/bin/clang++      clang++      /usr/bin/clang++-3.6           \
        --slave   /usr/bin/clang-check  clang-check  /usr/bin/clang-check-3.6       \
        --slave   /usr/bin/clang-query  clang-query  /usr/bin/clang-query-3.6       \
        --slave   /usr/bin/clang-tblgen clang-tblgen /usr/bin/clang-tblgen-3.6      \
        --slave   /usr/bin/clang-tidy   clang-tidy   /usr/bin/clang-tidy-3.6        \
        --slave   /usr/bin/llvm-config  llvm-config  /usr/bin/llvm-config-3.6       \
        --slave   /usr/bin/scan-build   scan-build   /usr/bin/scan-build-3.6        \
        --slave   /usr/bin/scan-view    scan-view    /usr/bin/scan-view-3.6

    # Add clang to the alternatives for cc / c++
    update-alternatives \
        --install /usr/bin/cc           cc           /usr/bin/clang         50
    update-alternatives \
        --install /usr/bin/c++          c++          /usr/bin/clang++       50

    # Use clang as the default compiler.
    update-alternatives --set cc  /usr/bin/clang
    update-alternatives --set c++ /usr/bin/clang++
}

function build_musl() {
    cd /root

    # Download
    curl -LO http://www.musl-libc.org/releases/musl-${MUSL_VERSION}.tar.gz
    tar zxvf musl-${MUSL_VERSION}.tar.gz
    cd musl-${MUSL_VERSION}

    # Build
    ./configure
    make -j4
    make install
}

function build_llvm() {
    cd /root

    if [ ! -d llvm ]
    then
        git clone --depth 1 -b release_36 https://github.com/llvm-mirror/llvm
        git clone --depth 1 -b release_36 https://github.com/llvm-mirror/clang llvm/tools/clang
        git clone --depth 1 -b release_36 https://github.com/llvm-mirror/compiler-rt llvm/projects/compiler-rt
    fi

    patch -Np1 -i /root/llvm-musl.patch

    mkdir -p llvm-build
    cd llvm-build

    # Note: the targets we build are the ones that musl supports
    cmake ../llvm -G Ninja                              \
        -DCMAKE_BUILD_TYPE=Release                      \
        "-DLLVM_TARGETS_TO_BUILD=X86;ARM;Mips;PowerPC"  \
        -DCMAKE_C_COMPILER=clang                        \
        -DCMAKE_CXX_COMPILER=clang++                    \
        -DCMAKE_INSTALL_PREFIX=/opt/clang-3.6

    # Build and install
    cmake --build .
    cmake --build . --target install
}

function use_new_clang() {
    # Remove old alternative for the installed clang-3.6 package
    update-alternatives --remove clang /usr/bin/clang-3.6

    # Remove clang-3.6 and all associated packages
    DEBIAN_FRONTEND=noninteractive apt-get purge -qyy clang-3.6
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -qyy

    # Use our newly-built clang-3.6 as default clang + tools
    update-alternatives \
        --install /usr/bin/clang        clang        /opt/clang-3.6/bin/clang     50      \
        --slave   /usr/bin/clang++      clang++      /opt/clang-3.6/bin/clang++           \
        --slave   /usr/bin/clang-check  clang-check  /opt/clang-3.6/bin/clang-check       \
        --slave   /usr/bin/clang-tidy   clang-tidy   /opt/clang-3.6/bin/clang-tidy        \
        --slave   /usr/bin/llvm-config  llvm-config  /opt/clang-3.6/bin/llvm-config

    # TODO: figure out how to build/install these?
    #    --slave   /usr/bin/clang-query  clang-query  /opt/clang-3.6/bin/clang-query       \
    #    --slave   /usr/bin/clang-tblgen clang-tblgen /opt/clang-3.6/bin/clang-tblgen      \
    #    --slave   /usr/bin/scan-build   scan-build   /opt/clang-3.6/bin/scan-build        \
    #    --slave   /usr/bin/scan-view    scan-view    /opt/clang-3.6/bin/scan-view
}

function doit() {
    install_packages
    build_musl
    build_llvm
    use_new_clang

    install -m 0755 /root/musl-clang /usr/bin/musl-clang
}

doit
