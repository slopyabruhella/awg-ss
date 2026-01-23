# -------------------------------
# Build amneziawg-go
# -------------------------------
FROM golang:1.24.5 AS builder

ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /amneziawg-go

RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git . --depth=1 \
    && go mod download \
    && go mod verify \
    && CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH GOARM=${TARGETVARIANT#v} \
       go build -ldflags '-s -w' -v -o amneziawg-go

# -------------------------------
# Final image
# -------------------------------
FROM alpine:3.23

ARG TARGETARCH
ARG AWGTOOLS_RELEASE=1.0.20250706

# runtime & build deps
RUN apk --no-cache add \
    iproute2 \
    iptables \
    bash \
    curl \
    wget \
    openresolv \
    dumb-init \
    libressl4.2-libcrypto \
    libsodium
RUN apk --no-cache add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    shadowsocks-rust
RUN apk --no-cache add --virtual .build-deps \
    dpkg \
    unzip \
    git \
    build-base \
    linux-headers

# build amneziawg-tools
RUN git clone https://github.com/amnezia-vpn/amneziawg-tools.git /amneziawg-tools --depth=1 \
    && cd /amneziawg-tools/src \
    && make \
    && make install \
    && ln -s /usr/local/bin/awg /usr/bin/wg \
    && ln -s /usr/local/bin/awg-quick /usr/bin/wg-quick \
    && cd / \
    && rm -rf /amneziawg-tools \
    && apk del .build-deps


# copy the amneziawg-go binary from builder stage
COPY --from=builder /amneziawg-go/amneziawg-go /usr/bin/

RUN sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' /usr/bin/awg-quick

COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 4096/tcp 4096/udp
EXPOSE 4097/tcp 4097/udp
EXPOSE 4098/tcp 4098/udp
EXPOSE 4099/tcp 4099/udp

HEALTHCHECK --interval=1m --timeout=5s --retries=3 \
    CMD /usr/bin/timeout 5s /bin/sh -c "awg show | grep interface || exit 1"

ENTRYPOINT ["/usr/bin/dumb-init", "/init.sh"]
