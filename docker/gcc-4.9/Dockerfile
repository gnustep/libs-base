FROM gcc:4.9

ENV DEBIAN_FRONTEND=noninteractive

# Switch to the Debian archive.
RUN sed -i \
      -e 's|deb.debian.org|archive.debian.org|g' \
      -e 's|security.debian.org|archive.debian.org|g' \
      /etc/apt/sources.list && \
    printf 'Acquire::Check-Valid-Until "false";\n' \
      >/etc/apt/apt.conf.d/99no-check-valid

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      autoconf \
      automake \
      ca-certificates \
      cmake \
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

RUN gcc --version && \
    echo '@interface Foo @end @implementation Foo @end' > test.m && \
    gcc -c test.m && \
    rm -f test.*
