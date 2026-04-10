#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

FROM alpine:3.23

ENV EASYRSA_VER=3.2.6
WORKDIR /opt/src

RUN set -x \
    && apk add --no-cache \
         bash bind-tools coreutils iproute2 iptables iptables-legacy ip6tables \
         openssl openvpn wget \
    && cd /sbin \
    && for fn in iptables iptables-save iptables-restore \
                 ip6tables ip6tables-save ip6tables-restore; do \
         ln -fs xtables-legacy-multi "$fn"; done \
    && wget -t 3 -T 30 -nv -O /opt/src/easyrsa.tgz \
         "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VER}/EasyRSA-${EASYRSA_VER}.tgz" \
    && tar xzf /opt/src/easyrsa.tgz -C /opt/src/ \
    && mv "/opt/src/EasyRSA-${EASYRSA_VER}" /opt/src/easyrsa \
    && chown -R root:root /opt/src/easyrsa \
    && rm -f /opt/src/easyrsa.tgz \
    && ln -s /opt/src/easyrsa/easyrsa /usr/local/bin/easyrsa \
    && easyrsa --version

COPY ./run.sh /opt/src/run.sh
COPY ./manage.sh /opt/src/manage.sh
COPY ./LICENSE.md /opt/src/LICENSE.md
RUN chmod 755 /opt/src/run.sh /opt/src/manage.sh \
    && ln -s /opt/src/manage.sh /usr/local/bin/ovpn_manage

EXPOSE 1194/udp
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="OpenVPN Server on Docker" \
    org.opencontainers.image.description="Docker image to run an OpenVPN server, with clients managed via a helper script." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-openvpn" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-openvpn" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-openvpn"