# Build the same Ruby minor the native-gem smoke jobs use on each actual
# distro. Ubuntu 22.04's system Ruby is older than this gem supports.
ARG BASE
FROM ${BASE}

RUN if command -v apk >/dev/null; then \
      apk add --no-cache bash build-base linux-headers openssl-dev yaml-dev \
        readline-dev zlib-dev libffi-dev ca-certificates curl tar gzip jq file; \
    else \
      apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash build-essential libssl-dev libyaml-dev libreadline-dev zlib1g-dev \
        libffi-dev ca-certificates curl tar gzip jq file \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Ruby source and digest from ruby-build's 3.4.1 definition. This is a test
# runtime, not a change to the supported Ruby floor or a product release.
RUN curl --fail --location --retry 3 https://cache.ruby-lang.org/pub/ruby/3.4/ruby-3.4.1.tar.gz -o /tmp/ruby.tar.gz \
    && echo '3d385e5d22d368b064c817a13ed8e3cc3f71a7705d7ed1bae78013c33aa7c87f  /tmp/ruby.tar.gz' | sha256sum -c - \
    && tar -xzf /tmp/ruby.tar.gz -C /tmp \
    && cd /tmp/ruby-3.4.1 \
    && ./configure --prefix=/opt/ruby --disable-install-doc --disable-yjit \
    && make -j2 && make install \
    && rm -rf /tmp/ruby-3.4.1 /tmp/ruby.tar.gz
ENV PATH="/opt/ruby/bin:${PATH}"
