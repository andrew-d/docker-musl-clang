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
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -yy
    DEBIAN_FRONTEND=noninteractive apt-get install -yy \
        automake            \
        bison               \
        clang-3.6           \
        cmake               \
        curl                \
        file                \
        flex                \
        git                 \
        lldb-3.6            \
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
        --slave   /usr/bin/lldb         lldb         /usr/bin/lldb-3.6              \
        --slave   /usr/bin/llvm-config  llvm-config  /usr/bin/llvm-config-3.6       \
        --slave   /usr/bin/scan-build   scan-build   /usr/bin/scan-build-3.6        \
        --slave   /usr/bin/scan-view    scan-view    /usr/bin/scan-view-3.6
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

function build_compiler_rt() {
    cd /root

    git clone --depth 1 -b release_36 https://github.com/llvm-mirror/compiler-rt
    cd compiler-rt
    patch -p4 < /root/compiler-rt-musl.patch

    cd /root
    mkdir compiler-rt-build && cd compiler-rt-build
    cmake ../compiler-rt -DLLVM_CONFIG_PATH=$(which llvm-config)
    make
}

function doit() {
    install_packages
    build_musl
    build_compiler_rt

    install -m 0755 /root/musl-clang /usr/bin/musl-clang
}

doit
