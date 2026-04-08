[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Сервер OpenVPN на Docker

[![Build Status](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-openvpn/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Docker-образ для запуска сервера OpenVPN. Основан на Alpine Linux с OpenVPN и EasyRSA. Разработан как простой, современный и легко поддерживаемый.

- Автоматическая генерация PKI, сертификатов сервера и конфигурации клиента при первом запуске
- Управление клиентами через вспомогательный скрипт (`ovpn_manage`)
- Современный набор шифров: AES-128-GCM, SHA256, tls-crypt
- Поддержка IPv6 при наличии публичного IPv6-адреса на сервере (см. [требования](#поддержка-ipv6))
- Постоянное хранение данных через Docker volume
- Поддержка нескольких архитектур: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

**Также доступно:** Docker-образы для [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-ru.md), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-ru.md), [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-ru.md), [LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) и [Whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md).

## Быстрый старт

**Шаг 1.** Запустите сервер OpenVPN:

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

При первом запуске сервер автоматически генерирует PKI, сертификат сервера, ключ TLS crypt и конфигурацию клиента с именем `client.ovpn`.

**Шаг 2.** Скопируйте конфигурацию клиента на локальную машину:

```bash
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

Импортируйте `client.ovpn` в ваш клиент OpenVPN для подключения.

В качестве альтернативы вы можете [настроить OpenVPN без Docker](https://github.com/hwdsl2/openvpn-install/blob/master/README-ru.md). Чтобы узнать больше о том, как использовать этот образ, прочитайте разделы ниже.

## Требования

- Linux-сервер с публичным IP-адресом или DNS-именем
- Установленный Docker
- Открытый в файрволе порт VPN (по умолчанию UDP 1194, или настроенный порт/протокол)

## Загрузка

Получите образ из [реестра Docker Hub](https://hub.docker.com/r/hwdsl2/openvpn-server/):

```bash
docker pull hwdsl2/openvpn-server
```

Либо загрузите из [Quay.io](https://quay.io/repository/hwdsl2/openvpn-server):

```bash
docker pull quay.io/hwdsl2/openvpn-server
docker image tag quay.io/hwdsl2/openvpn-server hwdsl2/openvpn-server
```

Поддерживаемые платформы: `linux/amd64`, `linux/arm64` и `linux/arm/v7`.

## Переменные окружения

Все переменные необязательны. Если не заданы, автоматически используются безопасные значения по умолчанию.

Этот Docker-образ использует следующие переменные, которые можно задать в файле `env` (см. [пример](vpn.env.example)):

| Переменная | Описание | Значение по умолчанию |
|---|---|---|
| `VPN_DNS_NAME` | Полное доменное имя (FQDN) сервера | Автоопределение публичного IP |
| `VPN_PUBLIC_IP` | Публичный IPv4-адрес сервера | Автоопределение |
| `VPN_PUBLIC_IP6` | Публичный IPv6-адрес сервера | Автоопределение |
| `VPN_PROTO` | Протокол VPN: `udp` или `tcp` | `udp` |
| `VPN_PORT` | Порт VPN (1–65535) | `1194` |
| `VPN_CLIENT_NAME` | Имя первого сгенерированного конфига клиента | `client` |
| `VPN_DNS_SRV1` | Основной DNS-сервер, передаваемый клиентам | `8.8.8.8` |
| `VPN_DNS_SRV2` | Резервный DNS-сервер, передаваемый клиентам | `8.8.4.4` |

**Примечание:** В файле `env` можно заключать значения в одинарные кавычки, например `VAR='значение'`. Не добавляйте пробелы вокруг `=`. Если вы изменили `VPN_PORT` или `VPN_PROTO`, соответственно обновите флаг `-p` в команде `docker run`.

Пример использования файла `env`:

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

Файл env монтируется в контейнер через bind mount, поэтому изменения применяются при каждом перезапуске контейнера без его пересоздания.

## Управление клиентами

Используйте `docker exec` для управления клиентами с помощью вспомогательного скрипта `ovpn_manage`.

**Добавить нового клиента:**

```bash
docker exec openvpn ovpn_manage --addclient alice
docker cp openvpn:/etc/openvpn/clients/alice.ovpn .
```

**Экспортировать конфигурацию клиента** (выводится в stdout):

```bash
docker exec openvpn ovpn_manage --exportclient alice > alice.ovpn
```

**Список клиентов:**

```bash
docker exec openvpn ovpn_manage --listclients
```

**Отозвать клиента** (будет запрошено подтверждение):

```bash
docker exec -it openvpn ovpn_manage --revokeclient alice
# Или отозвать без запроса подтверждения:
docker exec openvpn ovpn_manage --revokeclient alice -y
```

## Постоянные данные

Все данные сервера и клиентов хранятся в Docker volume (`/etc/openvpn` внутри контейнера):

```
/etc/openvpn/
├── server/
│   ├── server.conf         # Конфигурация сервера OpenVPN
│   ├── ca.crt              # Сертификат CA
│   ├── server.crt          # Сертификат сервера
│   ├── server.key          # Закрытый ключ сервера
│   ├── tc.key              # Ключ TLS crypt
│   ├── dh.pem              # Параметры DH
│   ├── crl.pem             # Список отозванных сертификатов
│   ├── client-common.txt   # Шаблон конфигурации клиента
│   ├── ipp.txt             # Сохранение пула IP-адресов
│   └── easy-rsa/pki/       # Полный каталог PKI
└── clients/
    ├── client.ovpn         # Конфигурация первого клиента
    └── alice.ovpn          # Дополнительные клиенты
```

Сделайте резервную копию Docker volume для сохранения всех ключей и конфигураций клиентов.

## Поддержка IPv6

Если Docker-хост имеет публичный (глобальный одноадресный) IPv6-адрес и выполнены приведённые ниже требования, поддержка IPv6 автоматически включается при запуске контейнера. Никакой дополнительной настройки не требуется.

**Требования:**
- Docker-хост должен иметь маршрутизируемый глобальный одноадресный IPv6-адрес (начинающийся с `2` или `3`). Локальные адреса канала (`fe80::/10`) не подходят.
- Для Docker-контейнера должна быть включена поддержка IPv6. См. [Enable IPv6 support in Docker](https://docs.docker.com/engine/daemon/ipv6/).

Чтобы включить IPv6 для Docker-контейнера, сначала включите IPv6 в демоне Docker, добавив следующее в файл `/etc/docker/daemon.json` на Docker-хосте, затем перезапустите Docker:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fddd:1::/64"
}
```

После этого пересоздайте Docker-контейнер. Чтобы проверить работу IPv6, подключитесь к VPN и проверьте ваш IPv6-адрес, например, с помощью [test-ipv6.com](https://test-ipv6.com).

## Использование docker-compose

```bash
cp vpn.env.example vpn.env
# При необходимости отредактируйте vpn.env, затем:
docker compose up -d
docker cp openvpn:/etc/openvpn/clients/client.ovpn .
```

Пример `docker-compose.yml` (уже включён):

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

## Обновление Docker-образа

Для обновления Docker-образа и контейнера сначала [загрузите](#загрузка) последнюю версию:

```bash
docker pull hwdsl2/openvpn-server
```

Если Docker-образ уже актуален, вы увидите:

```
Status: Image is up to date for hwdsl2/openvpn-server:latest
```

В противном случае будет загружена последняя версия. Удалите и пересоздайте контейнер, следуя инструкциям из раздела [Быстрый старт](#быстрый-старт). Ваши данные сохранены в volume `openvpn-data`.

## Технические детали

- Базовый образ: `alpine:3.23`
- OpenVPN: последняя версия из пакетов Alpine
- EasyRSA: 3.2.6 (включён в образ при сборке)
- Шифр: AES-128-GCM
- Аутентификация: SHA256
- Обмен ключами: tls-crypt (HMAC + шифрование)
- Параметры DH: предопределённая группа ffdhe2048 (RFC 7919)
- Сертификаты клиентов: срок действия 10 лет
- Подсеть VPN: `10.8.0.0/24`
- Подсеть VPN IPv6: `fddd:1194:1194:1194::/64` (при наличии IPv6 на сервере)

## Лицензия

**Примечание:** Программные компоненты внутри предсобранного образа (такие как OpenVPN и EasyRSA) распространяются под соответствующими лицензиями, выбранными их правообладателями. При использовании любого предсобранного образа пользователь несёт ответственность за соблюдение всех соответствующих лицензий на программное обеспечение, содержащееся в образе.

Copyright (C) 2026 Lin Song   
Эта работа распространяется под [лицензией MIT](https://opensource.org/licenses/MIT).

Этот проект частично основан на работе [Nyr и участников проекта](https://github.com/Nyr/openvpn-install), распространяемой под [лицензией MIT](https://github.com/Nyr/openvpn-install/blob/master/LICENSE).