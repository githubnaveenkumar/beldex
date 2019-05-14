# Multistage docker build, requires docker 17.05

# builder stage
FROM ubuntu:16.04 as builder

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install \
        ca-certificates \
        cmake \
        g++ \
        make \
        pkg-config \
        graphviz \
        doxygen \
        git \
        curl \
        libtool-bin \
        autoconf \
        automake \
        bzip2 \
        xsltproc \
        gperf \
        unzip

WORKDIR /usr/local

#Cmake
ARG CMAKE_VERSION=3.12.1
ARG CMAKE_VERSION_DOT=v3.12
ARG CMAKE_HASH=c53d5c2ce81d7a957ee83e3e635c8cda5dfe20c9d501a4828ee28e1615e57ab2 
RUN set -ex \
    && curl -s -O https://cmake.org/files/${CMAKE_VERSION_DOT}/cmake-${CMAKE_VERSION}.tar.gz \
    && echo "${CMAKE_HASH}  cmake-${CMAKE_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf cmake-${CMAKE_VERSION}.tar.gz \
    && cd cmake-${CMAKE_VERSION} \
    && ./configure \
    && make \
    && make install

ENV ANDROID_NDK_REVISION 17b
ENV BOOST_VERSION 1_67_0
ENV BOOST_VERSION_DOT 1.67.0

## Getting Android NDK
RUN curl -s -O https://dl.google.com/android/repository/android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && unzip android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
    && rm -f android-ndk-r${ANDROID_NDK_REVISION}-linux-x86_64.zip \
&& ln -s android-ndk-r${ANDROID_NDK_REVISION} ndk

## Installing toolchains
RUN ndk/build/tools/make_standalone_toolchain.py --api 21 --stl=libc++ --arch arm --install-dir /opt/android/tool/arm \
    && ndk/build/tools/make_standalone_toolchain.py --api 21 --stl=libc++ --arch arm64 --install-dir /opt/android/tool/arm64 \
    && ndk/build/tools/make_standalone_toolchain.py --api 21 --stl=libc++ --arch x86 --install-dir /opt/android/tool/x86 \
    && ndk/build/tools/make_standalone_toolchain.py --api 21 --stl=libc++ --arch x86_64 --install-dir /opt/android/tool/x86_64

## Building OpenSSL
RUN git clone https://github.com/m2049r/android-openssl.git --depth=1 \
    && curl -L -s -O https://github.com/openssl/openssl/archive/OpenSSL_1_0_2l.tar.gz \
    && cd android-openssl \
    && tar xfz ../OpenSSL_1_0_2l.tar.gz \
    && rm -f ../OpenSSL_1_0_2l.tar.gz \
    && ANDROID_NDK_ROOT=/opt/android/ndk ./build-all-arch.sh

RUN [ "/bin/bash", "-c", "mkdir -p /opt/android/build/openssl/{arm,arm64,x86,x86_64} \
    && cp -a /opt/android/android-openssl/prebuilt/armeabi /opt/android/build/openssl/arm/lib \
    && cp -a /opt/android/android-openssl/prebuilt/arm64-v8a /opt/android/build/openssl/arm64/lib \
    && cp -a /opt/android/android-openssl/prebuilt/x86 /opt/android/build/openssl/x86/lib \
    && cp -a /opt/android/android-openssl/prebuilt/x86_64 /opt/android/build/openssl/x86_64/lib \
    && cp -aL /opt/android/android-openssl/openssl-OpenSSL_1_0_2l/include/openssl/ /opt/android/build/openssl/include \
    && ln -s /opt/android/build/openssl/include /opt/android/build/openssl/arm/include \
    && ln -s /opt/android/build/openssl/include /opt/android/build/openssl/arm64/include \
    && ln -s /opt/android/build/openssl/include /opt/android/build/openssl/x86/include \
    && ln -s /opt/android/build/openssl/include /opt/android/build/openssl/x86_64/include \
    && ln -sf /opt/android/build/openssl/include /opt/android/tool/arm/sysroot/usr/include/openssl \
    && ln -sf /opt/android/build/openssl/arm/lib/*.so /opt/android/tool/arm/sysroot/usr/lib \
    && ln -sf /opt/android/build/openssl/include /opt/android/tool/arm64/sysroot/usr/include/openssl \
    && ln -sf /opt/android/build/openssl/arm64/lib/*.so /opt/android/tool/arm64/sysroot/usr/lib \
    && ln -sf /opt/android/build/openssl/include /opt/android/tool/x86/sysroot/usr/include/openssl \
    && ln -sf /opt/android/build/openssl/x86/lib/*.so /opt/android/tool/x86/sysroot/usr/lib \
    && ln -sf /opt/android/build/openssl/include /opt/android/tool/x86_64/sysroot/usr/include/openssl \
    && ln -sf /opt/android/build/openssl/x86_64/lib/*.so /opt/android/tool/x86_64/sysroot/usr/lib64" ]

## Building Boost
RUN cd /opt/android \
    && curl -s -L -o  boost_${BOOST_VERSION}.tar.bz2 https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION_DOT}/boost_${BOOST_VERSION}.tar.bz2/download \
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && rm -f /usr/boost_${BOOST_VERSION}.tar.bz2 \
    && cd boost_${BOOST_VERSION} \
&& ./bootstrap.sh

## Building Boost
RUN cd boost_${BOOST_VERSION} \
    && PATH=/opt/android/tool/arm/arm-linux-androideabi/bin:/opt/android/tool/arm/bin:$PATH ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --build-dir=android-arm --prefix=/opt/android/build/boost/arm --includedir=/opt/android/build/boost/include toolset=clang threading=multi threadapi=pthread target-os=android install \
    && PATH=/opt/android/tool/arm64/aarch64-linux-android/bin:/opt/android/tool/arm64/bin:$PATH ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --build-dir=android-arm64 --prefix=/opt/android/build/boost/arm64 --includedir=/opt/android/build/boost/include toolset=clang threading=multi threadapi=pthread target-os=android install \
    && PATH=/opt/android/tool/x86/i686-linux-android/bin:/opt/android/tool/x86/bin:$PATH ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --build-dir=android-x86 --prefix=/opt/android/build/boost/x86 --includedir=/opt/android/build/boost/include toolset=clang threading=multi threadapi=pthread target-os=android install \
    && PATH=/opt/android/tool/x86_64/x86_64-linux-android/bin:/opt/android/tool/x86_64/bin:$PATH ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --build-dir=android-x86_64 --prefix=/opt/android/build/boost/x86_64 --includedir=/opt/android/build/boost/include toolset=clang threading=multi threadapi=pthread target-os=android install \
    && ln -sf ../include /opt/android/build/boost/arm \
    && ln -sf ../include /opt/android/build/boost/arm64 \
    && ln -sf ../include /opt/android/build/boost/x86 \
&& ln -sf ../include /opt/android/build/boost/x86_64



# ZMQ
ARG ZMQ_VERSION=v4.2.5
ARG ZMQ_HASH=d062edd8c142384792955796329baf1e5a3377cd
RUN set -ex \
    && git clone https://github.com/zeromq/libzmq.git -b ${ZMQ_VERSION} --depth=1 \
    && cd libzmq \
    && test `git rev-parse HEAD` = ${ZMQ_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install \
    && ldconfig

# ncurses
ARG NCURSES_VERSION=6.1
ARG READLINE_HASH=750d437185286f40a369e1e4f4764eda932b9459b5ec9a731628393dd3d32334
RUN set -ex \
    && curl -s -O https://storage.googleapis.com/ncurses/ncurses-6.1.tar.gz \
    && tar -xzf ncurses-${NCURSES_VERSION}.tar.gz \
    && cd ncurses-${NCURSES_VERSION} \
    && CFLAGS="-fPIC" CXXFLAGS="-P -fPIC" ./configure --enable-termcap --with-termlib \
    && make \
    && make install

# zmq.hpp
ARG CPPZMQ_VERSION=v4.3.0
ARG CPPZMQ_HASH=213da0b04ae3b4d846c9abc46bab87f86bfb9cf4
RUN set -ex \
    && git clone https://github.com/zeromq/cppzmq.git -b ${CPPZMQ_VERSION} --depth=1 \
    && cd cppzmq \
    && test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
    && mv *.hpp /usr/local/include

# Readline
ARG READLINE_VERSION=7.0
ARG READLINE_HASH=750d437185286f40a369e1e4f4764eda932b9459b5ec9a731628393dd3d32334
RUN set -ex \
    && curl -s -O https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz \
    && echo "${READLINE_HASH}  readline-${READLINE_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf readline-${READLINE_VERSION}.tar.gz \
    && cd readline-${READLINE_VERSION} \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
    && make \
    && make install

# Sodium
ARG SODIUM_VERSION=1.0.16
ARG SODIUM_HASH=675149b9b8b66ff44152553fb3ebf9858128363d
RUN set -ex \
    && git clone https://github.com/jedisct1/libsodium.git -b ${SODIUM_VERSION} --depth=1 \
    && cd libsodium \
    && test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
    && make \
    && make check \
    && make install

## Building Sodium
RUN cd /opt/android/libsodium \
    && PATH=/opt/android/tool/arm/arm-linux-androideabi/bin:/opt/android/tool/arm/bin:$PATH ; CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix=/opt/android/build/libsodium/arm --host=arm-linux-androideabi --enable-static --disable-shared && make && make install && make clean \
    && PATH=/opt/android/tool/arm64/aarch64-linux-android/bin:/opt/android/tool/arm64/bin:$PATH ; CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix=/opt/android/build/libsodium/arm64 --host=aarch64-linux-android --enable-static --disable-shared && make && make install && make clean \
    && PATH=/opt/android/tool/x86/i686-linux-android/bin:/opt/android/tool/x86/bin:$PATH ; CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix=/opt/android/build/libsodium/x86 --host=i686-linux-android --enable-static --disable-shared && make && make install && make clean \
&& PATH=/opt/android/tool/x86_64/x86_64-linux-android/bin:/opt/android/tool/x86_64/bin:$PATH ; CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --prefix=/opt/android/build/libsodium/x86_64 --host=x86_64-linux-android --enable-static --disable-shared && make && make install && make clean

# Building Loki from the latest commit on Android branch, this should be kept up to date with master
# with the necessary fixes by crtlib and m2049r to build for mobile.
ARG LOKI_COMMIT_HASH=c81930425af9e2b61aec7d051839d420502795e2
RUN cd /opt/android \
    && git clone -b LokiAndroidWallet https://github.com/doy-lee/loki.git --recursive --depth=1 \
    && cd loki \
    && test `git rev-parse HEAD` = ${LOKI_COMMIT_HASH} || exit 1 \
    && mkdir -p build/release \
    && ./build-all-arch.sh

# Uncomment this section to use loki from the docker directory if you want to
# easily build a custom version not depending on the specified branch above and
# comment out the section above that pulls from github.
# ADD loki /opt/android/loki
# RUN cd /opt/android/loki \
#      && rm -rf build \
#      && mkdir -p build/release \
#      && ./build-all-arch.sh

# Udev
ARG SODIUM_VERSION=1.0.16
ARG SODIUM_HASH=675149b9b8b66ff44152553fb3ebf9858128363d
RUN set -ex \
    && cd /opt/android \
    && git clone https://github.com/jedisct1/libsodium.git -b ${SODIUM_VERSION} --depth=1 \
    && cd libsodium \
    && test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
&& ./autogen.sh

# Libusb
ARG USB_VERSION=v1.0.22
ARG USB_HASH=0034b2afdcdb1614e78edaa2a9e22d5936aeae5d
RUN set -ex \
    && git clone https://github.com/libusb/libusb.git -b ${USB_VERSION} \
    && cd libusb \
    && test `git rev-parse HEAD` = ${USB_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --disable-shared \
    && make \
    && make install

# Hidapi
ARG HIDAPI_VERSION=hidapi-0.8.0-rc1
ARG HIDAPI_HASH=40cf516139b5b61e30d9403a48db23d8f915f52c
RUN set -ex \
    && git clone https://github.com/signal11/hidapi -b ${HIDAPI_VERSION} \
    && cd hidapi \
    && test `git rev-parse HEAD` = ${HIDAPI_HASH} || exit 1 \
    && ./bootstrap \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install

# Protobuf
ARG PROTOBUF_VERSION=v3.6.1
ARG PROTOBUF_HASH=48cb18e5c419ddd23d9badcfe4e9df7bde1979b2
RUN set -ex \
    && git clone https://github.com/protocolbuffers/protobuf -b ${PROTOBUF_VERSION} \
    && cd protobuf \
    && test `git rev-parse HEAD` = ${PROTOBUF_HASH} || exit 1 \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install \
    && ldconfig

WORKDIR /src
COPY . .

ENV USE_SINGLE_BUILDDIR=1
ARG NPROC
RUN set -ex && \
    git submodule init && git submodule update && \
    rm -rf build && \
    if [ -z "$NPROC" ] ; \
    then make -j$(nproc) release-static ; \
    else make -j$NPROC release-static ; \
    fi

# runtime stage
FROM ubuntu:16.04

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt
COPY --from=builder /src/build/release/bin /usr/local/bin/

# Contains the blockchain
VOLUME /root/.beldex

# Generate your wallet via accessing the container and run:
# cd /wallet
# beldex-wallet-cli
VOLUME /wallet

EXPOSE 19090
EXPOSE 19091

ENTRYPOINT ["beldexd", "--p2p-bind-ip=0.0.0.0", "--p2p-bind-port=19090", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=19091", "--non-interactive", "--confirm-external-bind"]
