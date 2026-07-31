FROM gcc:4.9

ENV DEBIAN_FRONTEND=noninteractive

RUN cat >/etc/apt/sources.list <<EOF
deb http://archive.debian.org/debian jessie main
EOF

RUN printf 'Acquire::Check-Valid-Until "false";\nAcquire::AllowInsecureRepositories "true";\n' \
    >/etc/apt/apt.conf.d/99archive


RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --force-yes --no-install-recommends \
      build-essential \
      autoconf \
      automake \
      ca-certificates \
      wget \
      tar \
      bzip2 \
      make \
      flex \
      bison \
      git \
      libgmp-dev \
      libmpfr-dev \
      libmpc-dev \
      libcurl4-gnutls-dev \
      libffi-dev \
      libgnutls28-dev \
      libicu-dev \
      libssl-dev \
      libtool \
      libxml2-dev \
      libxslt1-dev \
      pkg-config \
      zlib1g-dev \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget https://ftp.gnu.org/gnu/gcc/gcc-4.9.4/gcc-4.9.4.tar.bz2 && \
    tar -xf gcc-4.9.4.tar.bz2 && \
    cd gcc-4.9.4 && \
    ./contrib/download_prerequisites && \
    mkdir build && \
    cd build && \
    ../configure \
      --prefix=/opt/gcc-4.9.4 \
      --enable-languages=c,c++,objc \
      --disable-multilib && \
    make -j$(nproc) && \
    make install

ENV PATH="/opt/gcc-4.9.4/bin:${PATH}"

RUN gcc --version && \
    echo '@interface Foo @end @implementation Foo @end' > test.m && \
    gcc -c test.m && \
    rm -f test.o test.m

RUN rm -rf gcc-4.9.4

