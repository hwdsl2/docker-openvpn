[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 在 Docker 上運行 OpenVPN 伺服器

[![Build Status](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml)

一個用於運行 OpenVPN 伺服器的 Docker 映像檔。基於 Alpine Linux，整合 OpenVPN 和 EasyRSA，設計目標是簡單、現代且易於維護。

- 首次啟動時自動產生 PKI、伺服器憑證以及客戶端設定
- 使用輔助腳本（`ovpn_manage`）進行客戶端管理
- 現代加密套件：AES-128-GCM、SHA256、tls-crypt
- 伺服器有公用 IPv6 位址時支援 IPv6（參見[要求](#ipv6-支援)）
- 使用 Docker 卷實現資料持久化
- 多架構支援：`linux/amd64`、`linux/arm64`、`linux/arm/v7`

**另提供：** [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh-Hant.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh-Hant.md) 與 [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh-Hant.md) 的 Docker 映像。

## 快速開始

**步驟 1.** 啟動 OpenVPN 伺服器：

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

首次啟動時，伺服器將自動產生 PKI、伺服器憑證、TLS 加密金鑰以及名為 `client.ovpn` 的客戶端設定檔。

**步驟 2.** 將客戶端設定檔複製到本機：

```bash
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

將 `client.ovpn` 匯入到 OpenVPN 客戶端即可連線。

另外，你也可以在不使用 Docker 的情況下[安裝 OpenVPN](https://github.com/hwdsl2/openvpn-install/blob/master/README-zh-Hant.md)。若要了解更多關於如何使用本映像檔的資訊，請繼續閱讀以下部分。

## 系統需求

- 具有公用 IP 位址或 DNS 名稱的 Linux 伺服器
- 已安裝 Docker
- 防火牆中已開放 VPN 連接埠（預設 UDP 1194，或自訂連接埠/協定）

## 下載

從 [Docker Hub 映像檔倉庫](https://hub.docker.com/r/hwdsl2/openvpn-server/)取得映像檔：

```bash
docker pull hwdsl2/openvpn-server
```

或從 [Quay.io](https://quay.io/repository/hwdsl2/openvpn-server) 下載：

```bash
docker pull quay.io/hwdsl2/openvpn-server
docker image tag quay.io/hwdsl2/openvpn-server hwdsl2/openvpn-server
```

支援平台：`linux/amd64`、`linux/arm64` 和 `linux/arm/v7`。

## 環境變數

所有變數均為選用。未設定時將自動使用安全預設值。

此 Docker 映像檔使用以下變數，可以在 `env` 檔案中宣告（參見[範例](vpn.env.example)）：

| 變數 | 說明 | 預設值 |
|---|---|---|
| `VPN_DNS_NAME` | 伺服器的完整網域名稱 (FQDN) | 自動偵測公用 IP |
| `VPN_PUBLIC_IP` | 伺服器的公用 IPv4 位址 | 自動偵測 |
| `VPN_PUBLIC_IP6` | 伺服器的公用 IPv6 位址 | 自動偵測 |
| `VPN_PROTO` | VPN 協定：`udp` 或 `tcp` | `udp` |
| `VPN_PORT` | VPN 連接埠（1–65535） | `1194` |
| `VPN_CLIENT_NAME` | 產生的第一個客戶端設定名稱 | `client` |
| `VPN_DNS_SRV1` | 推送給客戶端的主要 DNS 伺服器 | `8.8.8.8` |
| `VPN_DNS_SRV2` | 推送給客戶端的次要 DNS 伺服器 | `8.8.4.4` |

**注：** 在 `env` 檔案中，不要在值周圍加上 `""` 或 `''`，也不要在 `=` 周圍加上空格。如果修改了 `VPN_PORT` 或 `VPN_PROTO`，請相應更新 `docker run` 命令中的 `-p` 參數。

使用 `env` 檔案的範例：

```bash
docker run \
    --name openvpn \
    --env-file ./vpn.env \
    --restart=always \
    -v openvpn-data:/etc/openvpn \
    -p 1194:1194/udp \
    -d --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    hwdsl2/openvpn-server
```

## 客戶端管理

使用 `docker exec` 配合 `ovpn_manage` 輔助腳本管理客戶端。

**新增客戶端：**

```bash
docker exec openvpn ovpn_manage --addclient alice
docker cp openvpn:/etc/openvpn/clients/alice.ovpn .
```

**匯出客戶端設定**（輸出至標準輸出）：

```bash
docker exec openvpn ovpn_manage --exportclient alice > alice.ovpn
```

**列出客戶端：**

```bash
docker exec openvpn ovpn_manage --listclients
```

**撤銷客戶端**（將提示確認）：

```bash
docker exec -it openvpn ovpn_manage --revokeclient alice
# 或不提示確認直接撤銷：
docker exec openvpn ovpn_manage --revokeclient alice -y
```

## 持久化資料

所有伺服器和客戶端資料均存放於 Docker 卷（容器內的 `/etc/openvpn`）中：

```
/etc/openvpn/
├── server/
│   ├── server.conf         # OpenVPN 伺服器設定
│   ├── ca.crt              # CA 憑證
│   ├── server.crt/key      # 伺服器憑證和金鑰
│   ├── tc.key              # TLS 加密金鑰
│   ├── dh.pem              # DH 參數
│   ├── crl.pem             # 憑證撤銷清單
│   ├── client-common.txt   # 客戶端設定範本
│   ├── ipp.txt             # IP 集區持久化
│   └── easy-rsa/pki/       # 完整 PKI 目錄
└── clients/
    ├── client.ovpn         # 第一個客戶端設定檔
    └── alice.ovpn          # 其他客戶端
```

備份 Docker 卷以保存所有金鑰和客戶端設定檔。

## IPv6 支援

如果 Docker 宿主機擁有公用（全域單播）IPv6 位址並且滿足以下要求，IPv6 支援將在容器啟動時自動啟用，無需手動設定。

**要求：**
- Docker 宿主機必須擁有可路由的全域單播 IPv6 位址（以 `2` 或 `3` 開頭）。連結本地位址（`fe80::/10`）不滿足要求。
- 必須為 Docker 容器啟用 IPv6。參見[在 Docker 中啟用 IPv6 支援](https://docs.docker.com/engine/daemon/ipv6/)。

要為 Docker 容器啟用 IPv6，首先在 Docker 宿主機上將以下內容新增至 `/etc/docker/daemon.json`，然後重新啟動 Docker：

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fddd:1::/64"
}
```

然後重新建立容器。要驗證 IPv6 是否正常運作，請連線至 VPN，然後檢查你的 IPv6 位址，例如使用 [test-ipv6.com](https://test-ipv6.com)。

## 使用 docker-compose

```bash
cp vpn.env.example vpn.env
# 如需修改，請編輯 vpn.env，然後：
docker compose up -d
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

## 更新 Docker 映像檔

要更新 Docker 映像檔和容器，請先[下載](#下載)最新版本：

```bash
docker pull hwdsl2/openvpn-server
```

如果 Docker 映像檔已是最新版本，將顯示：

```
Status: Image is up to date for hwdsl2/openvpn-server:latest
```

否則將下載最新版本。依照[快速開始](#快速開始)中的說明刪除並重新建立容器。資料保存在 `openvpn-data` 卷中。

## 技術細節

- 基礎映像檔：`alpine:3.23`
- OpenVPN：來自 Alpine 套件的最新版本
- EasyRSA：3.2.6（建置時內建）
- 加密演算法：AES-128-GCM
- 驗證：SHA256
- 金鑰交換：tls-crypt（HMAC + 加密）
- DH 參數：預先定義的 ffdhe2048 群組（RFC 7919）
- 客戶端憑證：10 年有效期
- VPN 子網路：`10.8.0.0/24`
- IPv6 VPN 子網路：`fddd:1194:1194:1194::/64`（伺服器有 IPv6 時啟用）

## 授權條款

**注：** 預建映像檔中的軟體元件（如 OpenVPN 和 EasyRSA）遵循各自版權持有者所選擇的相應授權條款。對於任何預建映像檔的使用，映像檔使用者有責任確保其使用符合映像檔中所有軟體的相關授權條款。

Copyright (C) 2026 Lin Song
本作品依據[MIT 授權條款](https://opensource.org/licenses/MIT)授權。

本專案部分基於 [Nyr 和貢獻者](https://github.com/Nyr/openvpn-install)的工作，遵循 [MIT 授權條款](https://github.com/Nyr/openvpn-install/blob/master/LICENSE)。