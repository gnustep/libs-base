FROM gcc:4.9

ENV DEBIAN_FRONTEND=noninteractive

RUN cat >/etc/apt/sources.list <<EOF
deb http://archive.debian.org/debian jessie main
EOF

RUN printf 'Acquire::Check-Valid-Until "false";\nAcquire::AllowInsecureRepositories "true";\n' \
    >/etc/apt/apt.conf.d/99archive

RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --force-yes --no-install-recommends \
      autoconf \
      automake \
      ca-certificates \
      make \
      gcc-4.9 \
      g++-4.9 \
      gobjc-4.9 \
      libobjc-4.9-dev \
      git \
      libcurl4-gnutls-dev \
      libffi-dev \
      libgnutls28-dev \
      libicu-dev \
      libssl-dev \
      libtool \
      libxml2-dev \
      libxslt1-dev \
      pkg-config \
      zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN /usr/bingcc --version && \
    echo '@interface Foo @end @implementation Foo @end' > test.m && \
    /usr/bin/gcc -c test.m && \
    rm -f test.*

