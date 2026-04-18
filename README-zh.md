[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 在 Docker 上运行 OpenVPN 服务器

[![Build Status](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

一个用于运行 OpenVPN 服务器的 Docker 镜像。基于 Alpine Linux，集成 OpenVPN 和 EasyRSA，设计目标是简单、现代且易于维护。

**功能特性：**

- 首次启动时自动生成 PKI、服务器证书以及客户端配置
- 使用辅助脚本（`ovpn_manage`）进行客户端管理
- 现代加密套件：AES-128-GCM、SHA256、tls-crypt
- 为 VPN 客户端提供双栈 IPv4 和 IPv6 支持
- 通过 [GitHub Actions](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml) 自动构建和发布
- 使用 Docker 卷实现数据持久化
- 多架构支持：`linux/amd64`、`linux/arm64`、`linux/arm/v7`

**另提供：**

- 不使用 Docker：[OpenVPN 安装脚本](https://github.com/hwdsl2/openvpn-install/blob/master/README-zh.md)
- VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)
- AI/音频：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)

## 快速开始

**步骤 1.** 启动 OpenVPN 服务器：

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

首次启动时，服务器将自动生成 PKI、服务器证书、TLS 加密密钥以及名为 `client.ovpn` 的客户端配置文件。

**步骤 2.** 将客户端配置文件复制到本机：

```bash
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

将 `client.ovpn` 导入到 OpenVPN 客户端即可连接。

另外，你也可以在不使用 Docker 的情况下[安装 OpenVPN](https://github.com/hwdsl2/openvpn-install/blob/master/README-zh.md)。要了解更多有关如何使用本镜像的信息，请继续阅读以下部分。

## 系统要求

- 具有公网 IP 地址或 DNS 名称的 Linux 服务器
- 已安装 Docker
- 防火墙中已开放 VPN 端口（默认 UDP 1194，或自定义端口/协议）

## 下载

从 [Docker Hub 镜像仓库](https://hub.docker.com/r/hwdsl2/openvpn-server/)获取镜像：

```bash
docker pull hwdsl2/openvpn-server
```

或从 [Quay.io](https://quay.io/repository/hwdsl2/openvpn-server) 下载：

```bash
docker pull quay.io/hwdsl2/openvpn-server
docker image tag quay.io/hwdsl2/openvpn-server hwdsl2/openvpn-server
```

支持平台：`linux/amd64`、`linux/arm64` 和 `linux/arm/v7`。

## 环境变量

所有变量均为可选项。未设置时将自动使用安全默认值。

此 Docker 镜像使用以下变量，可以在 `env` 文件中声明（参见[示例](vpn.env.example)）：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `VPN_DNS_NAME` | 服务器的完全限定域名 (FQDN) | 自动检测公网 IP |
| `VPN_PUBLIC_IP` | 服务器的公网 IPv4 地址 | 自动检测 |
| `VPN_PUBLIC_IP6` | 服务器的公网 IPv6 地址 | 自动检测 |
| `VPN_PROTO` | VPN 协议：`udp` 或 `tcp` | `udp` |
| `VPN_PORT` | VPN 端口（1–65535） | `1194` |
| `VPN_CLIENT_NAME` | 生成的第一个客户端配置名称 | `client` |
| `VPN_DNS_SRV1` | 推送给客户端的主 DNS 服务器 | `8.8.8.8` |
| `VPN_DNS_SRV2` | 推送给客户端的备用 DNS 服务器 | `8.8.4.4` |

**注：** 在 `env` 文件中，可以用单引号括住变量值，例如 `VAR='值'`。不要在 `=` 周围添加空格。如果修改了 `VPN_PORT` 或 `VPN_PROTO`，请相应更新 `docker run` 命令中的 `-p` 参数。

使用 `env` 文件的示例：

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

env 文件以绑定挂载方式挂载到容器中，因此每次重启容器时都会读取最新的变量，无需重新创建容器。

## 客户端管理

使用 `docker exec` 配合 `ovpn_manage` 辅助脚本管理客户端。

**添加新客户端：**

```bash
docker exec openvpn ovpn_manage --addclient alice
docker cp openvpn:/etc/openvpn/clients/alice.ovpn .
```

**导出客户端配置**（输出到标准输出）：

```bash
docker exec openvpn ovpn_manage --exportclient alice > alice.ovpn
```

**列出客户端：**

```bash
docker exec openvpn ovpn_manage --listclients
```

**吊销客户端**（将提示确认）：

```bash
docker exec -it openvpn ovpn_manage --revokeclient alice
# 或不提示确认直接吊销：
docker exec openvpn ovpn_manage --revokeclient alice -y
```

## 持久化数据

所有服务器和客户端数据均存储在 Docker 卷（容器内的 `/etc/openvpn`）中：

```
/etc/openvpn/
├── server/
│   ├── server.conf         # OpenVPN 服务器配置
│   ├── ca.crt              # CA 证书
│   ├── server.crt          # 服务器证书
│   ├── server.key          # 服务器私钥
│   ├── tc.key              # TLS 加密密钥
│   ├── dh.pem              # DH 参数
│   ├── crl.pem             # 证书吊销列表
│   ├── client-common.txt   # 客户端配置模板
│   ├── ipp.txt             # IP 池持久化
│   └── easy-rsa/pki/       # 完整 PKI 目录
└── clients/
    ├── client.ovpn         # 第一个客户端配置
    └── alice.ovpn          # 其他客户端
```

备份 Docker 卷以保存所有密钥和客户端配置。

## IPv6 支持

如果 Docker 宿主机拥有公共（全局单播）IPv6 地址并且满足以下要求，IPv6 支持将在容器启动时自动启用，无需手动配置。

**要求：**
- Docker 宿主机必须拥有可路由的全局单播 IPv6 地址（以 `2` 或 `3` 开头）。链路本地地址（`fe80::/10`）不满足要求。
- 必须为 Docker 容器启用 IPv6。参见[在 Docker 中启用 IPv6 支持](https://docs.docker.com/engine/daemon/ipv6/)。

要为 Docker 容器启用 IPv6，首先在 Docker 宿主机上将以下内容添加到 `/etc/docker/daemon.json`，然后重启 Docker：

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fddd:1::/64"
}
```

然后重新创建容器。要验证 IPv6 是否正常工作，请连接到 VPN，然后检查你的 IPv6 地址，例如使用 [test-ipv6.com](https://test-ipv6.com)。

## 使用 docker-compose

```bash
cp vpn.env.example vpn.env
# 如需修改，请编辑 vpn.env，然后：
docker compose up -d
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

示例 `docker-compose.yml`（已包含在内）：

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

## 更新 Docker 镜像

要更新 Docker 镜像和容器，首先[下载](#下载)最新版本：

```bash
docker pull hwdsl2/openvpn-server
```

如果 Docker 镜像已是最新版本，将显示：

```
Status: Image is up to date for hwdsl2/openvpn-server:latest
```

否则将下载最新版本。按照[快速开始](#快速开始)中的说明删除并重新创建容器。数据保存在 `openvpn-data` 卷中。

## 技术细节

- 基础镜像：`alpine:3.23`
- OpenVPN：来自 Alpine 软件包的最新版本
- EasyRSA：3.2.6（构建时内置）
- 加密算法：AES-128-GCM
- 认证：SHA256
- 密钥交换：tls-crypt（HMAC + 加密）
- DH 参数：预定义 ffdhe2048 组（RFC 7919）
- 客户端证书：10 年有效期
- VPN 子网：`10.8.0.0/24`
- IPv6 VPN 子网：`fddd:1194:1194:1194::/64`（服务器有 IPv6 时启用）

## 授权协议

**注：** 预构建镜像中的软件组件（如 OpenVPN 和 EasyRSA）遵循各自版权持有者所选择的相应许可证。对于任何预构建镜像的使用，镜像用户有责任确保其使用符合镜像中所包含的所有软件的相关许可证。

Copyright (C) 2026 Lin Song   
本作品依据 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

本项目部分基于 [Nyr 和贡献者](https://github.com/Nyr/openvpn-install)的工作，遵循 [MIT 许可证](https://github.com/Nyr/openvpn-install/blob/master/LICENSE)。