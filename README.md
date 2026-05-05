[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# OpenVPN Server on Docker

[![Build Status](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Docker image to run an OpenVPN server. Based on Alpine Linux with OpenVPN and EasyRSA. Designed to be simple, modern, and maintainable.

**Features:**

- Automatically generates PKI, server certificates, and a client config on first start
- Client management via a helper script (`ovpn_manage`)
- Modern cipher suite: AES-128-GCM, SHA256, tls-crypt
- Dual-stack IPv4 and IPv6 support for VPN clients
- Automatically built and published via [GitHub Actions](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml)
- Persistent data via a Docker volume
- Multi-arch: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

**Also available:**

- Without Docker: [OpenVPN install script](https://github.com/hwdsl2/openvpn-install)
- VPN: [WireGuard](https://github.com/hwdsl2/docker-wireguard), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server), [Headscale](https://github.com/hwdsl2/docker-headscale)
- AI/Audio: [Self-hosted AI Stack](https://github.com/hwdsl2/docker-ai-stack)

## Quick start

**Step 1.** Start the OpenVPN server:

```bash
docker run \
    --name openvpn \
    --restart=always \
    -v openvpn-data:/etc/openvpn \
    -p 1194:1194/udp \
    -d --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    hwdsl2/openvpn-server
```

On first start, the server automatically generates a PKI, server certificate, TLS crypt key, and a client configuration named `client.ovpn`.

**Step 2.** Copy the client configuration to your local machine:

```bash
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

Import `client.ovpn` into your OpenVPN client to connect.

Alternatively, you may [set up OpenVPN without Docker](https://github.com/hwdsl2/openvpn-install). To learn more about how to use this image, read the sections below.

## Requirements

- A Linux server with a public IP address or DNS name
- Docker installed
- VPN port open in your firewall (UDP 1194 by default, or your configured port/protocol)

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/openvpn-server/):

```bash
docker pull hwdsl2/openvpn-server
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/openvpn-server):

```bash
docker pull quay.io/hwdsl2/openvpn-server
docker image tag quay.io/hwdsl2/openvpn-server hwdsl2/openvpn-server
```

Supported platforms: `linux/amd64`, `linux/arm64` and `linux/arm/v7`.

## Environment variables

All variables are optional. If not set, secure defaults are used automatically.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](vpn.env.example)):

| Variable | Description | Default |
|---|---|---|
| `VPN_DNS_NAME` | Fully qualified domain name (FQDN) of the server | Auto-detected public IP |
| `VPN_PUBLIC_IP` | Public IPv4 address of the server | Auto-detected |
| `VPN_PUBLIC_IP6` | Public IPv6 address of the server | Auto-detected |
| `VPN_PROTO` | VPN protocol: `udp` or `tcp` | `udp` |
| `VPN_PORT` | VPN port (1–65535) | `1194` |
| `VPN_CLIENT_NAME` | Name of the first client config generated | `client` |
| `VPN_DNS_SRV1` | Primary DNS server pushed to clients | `8.8.8.8` |
| `VPN_DNS_SRV2` | Secondary DNS server pushed to clients | `8.8.4.4` |

**Note:** In your `env` file, you may enclose values in single quotes, e.g. `VAR='value'`. Do not add spaces around `=`. If you change `VPN_PORT` or `VPN_PROTO`, update the `-p` flag in the `docker run` command accordingly.

Example using an `env` file:

```bash
docker run \
    --name openvpn \
    --restart=always \
    -v openvpn-data:/etc/openvpn \
    -v ./vpn.env:/vpn.env:ro \
    -p 1194:1194/udp \
    -d --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    hwdsl2/openvpn-server
```

The env file is bind-mounted into the container, so changes are picked up on every restart without recreating the container.

## Client management

Use `docker exec` to manage clients with the `ovpn_manage` helper script.

**Add a new client:**

```bash
docker exec openvpn ovpn_manage --addclient alice
docker cp openvpn:/etc/openvpn/clients/alice.ovpn .
```

**Export a client config** (prints to stdout):

```bash
docker exec openvpn ovpn_manage --exportclient alice > alice.ovpn
```

**List clients:**

```bash
docker exec openvpn ovpn_manage --listclients
```

**Revoke a client** (will prompt for confirmation):

```bash
docker exec -it openvpn ovpn_manage --revokeclient alice
# Or revoke without confirmation prompt:
docker exec openvpn ovpn_manage --revokeclient alice -y
```

## Persistent data

All server and client data is stored in the Docker volume (`/etc/openvpn` inside the container):

```
/etc/openvpn/
├── server/
│   ├── server.conf         # OpenVPN server configuration
│   ├── ca.crt              # CA certificate
│   ├── server.crt          # Server certificate
│   ├── server.key          # Server private key
│   ├── tc.key              # TLS crypt key
│   ├── dh.pem              # DH parameters
│   ├── crl.pem             # Certificate revocation list
│   ├── client-common.txt   # Client config template
│   ├── ipp.txt             # IP pool persistence
│   └── easy-rsa/pki/       # Full PKI directory
└── clients/
    ├── client.ovpn         # First client config
    └── alice.ovpn          # Additional clients
```

Back up the Docker volume to preserve all keys and client configurations.

## IPv6 support

If the Docker host has a public (global unicast) IPv6 address and the requirements below are met, IPv6 support is automatically enabled when the container starts. No manual configuration is needed.

**Requirements:**
- The Docker host must have a routable global unicast IPv6 address (starting with `2` or `3`). Link-local (`fe80::/10`) addresses are not sufficient.
- IPv6 must be enabled for the Docker container. See [Enable IPv6 support in Docker](https://docs.docker.com/engine/daemon/ipv6/).

To enable IPv6 for the Docker container, first enable IPv6 in the Docker daemon by adding the following to `/etc/docker/daemon.json` on the Docker host, then restart Docker:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fddd:1::/64"
}
```

After that, re-create the Docker container. To verify that IPv6 is working, connect to the VPN and check your IPv6 address, e.g. using [test-ipv6.com](https://test-ipv6.com).

## Using docker-compose

```bash
cp vpn.env.example vpn.env
# Edit vpn.env if needed, then:
docker compose up -d
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

Example `docker-compose.yml` (already included):

```yaml
services:
  openvpn:
    image: hwdsl2/openvpn-server
    container_name: openvpn
    restart: always
    ports:
      - "1194:1194/udp"
    volumes:
      - openvpn-data:/etc/openvpn
      - ./vpn.env:/vpn.env:ro
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1

volumes:
  openvpn-data:
```

## Update Docker image

To update the Docker image and container, first [download](#download) the latest version:

```bash
docker pull hwdsl2/openvpn-server
```

If the Docker image is already up to date, you should see:

```
Status: Image is up to date for hwdsl2/openvpn-server:latest
```

Otherwise, it will download the latest version. Remove and re-create the container using instructions from [Quick start](#quick-start). Your data is preserved in the `openvpn-data` volume.

## Technical details

- Base image: `alpine:3.23`
- OpenVPN: latest available from Alpine packages
- EasyRSA: 3.2.6 (bundled at build time)
- Cipher: AES-128-GCM
- Auth: SHA256
- Key exchange: tls-crypt (HMAC + encrypt)
- DH parameters: pre-defined ffdhe2048 group (RFC 7919)
- Client certificates: 10-year validity
- VPN subnet: `10.8.0.0/24`
- IPv6 VPN subnet: `fddd:1194:1194:1194::/64` (when server has IPv6)

## License

**Note:** The software components inside the pre-built image (such as OpenVPN and EasyRSA) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

This project is based in part on the work of [Nyr and contributors](https://github.com/Nyr/openvpn-install), licensed under the [MIT License](https://github.com/Nyr/openvpn-install/blob/master/LICENSE).