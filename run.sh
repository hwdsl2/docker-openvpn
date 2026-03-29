#!/bin/bash
#
# Docker script to configure and start an OpenVPN server
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of OpenVPN Docker image, available at:
# https://github.com/hwdsl2/docker-openvpn
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
# Copyright (C) 2013 Nyr
#
# Based on the work of Nyr and contributors at:
# https://github.com/Nyr/openvpn-install
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }
easyrsa_run() { echo "+ easyrsa $*" >&2; easyrsa "$@" >/dev/null 2>&1; }

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

check_dns_name() {
  FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$FQDN_REGEX"
}

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

if [ ! -e /dev/net/tun ] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
  exiterr "The TUN device is not available. Add '--device /dev/net/tun' to your docker run command."
fi

NET_IFACE=$(route 2>/dev/null | grep -m 1 '^default' | grep -o '[^ ]*$')
[ -z "$NET_IFACE" ] && NET_IFACE=$(ip -4 route list 0/0 2>/dev/null | grep -m 1 -o 'dev [^ ]*' | awk '{print $2}')
[ -z "$NET_IFACE" ] && NET_IFACE=eth0

# Read and sanitize environment variables
VPN_DNS_NAME=$(nospaces "$VPN_DNS_NAME")
VPN_DNS_NAME=$(noquotes "$VPN_DNS_NAME")
VPN_PUBLIC_IP=$(nospaces "$VPN_PUBLIC_IP")
VPN_PUBLIC_IP=$(noquotes "$VPN_PUBLIC_IP")
VPN_PROTO=$(nospaces "$VPN_PROTO")
VPN_PROTO=$(noquotes "$VPN_PROTO")
VPN_PORT=$(nospaces "$VPN_PORT")
VPN_PORT=$(noquotes "$VPN_PORT")
VPN_CLIENT_NAME=$(nospaces "$VPN_CLIENT_NAME")
VPN_CLIENT_NAME=$(noquotes "$VPN_CLIENT_NAME")
VPN_DNS_SRV1=$(nospaces "$VPN_DNS_SRV1")
VPN_DNS_SRV1=$(noquotes "$VPN_DNS_SRV1")
VPN_DNS_SRV2=$(nospaces "$VPN_DNS_SRV2")
VPN_DNS_SRV2=$(noquotes "$VPN_DNS_SRV2")

# Apply defaults
[ -z "$VPN_PROTO" ]    && VPN_PROTO=udp
[ -z "$VPN_PORT" ]     && VPN_PORT=1194
[ -z "$VPN_CLIENT_NAME" ] && VPN_CLIENT_NAME=client
[ -z "$VPN_DNS_SRV1" ] && VPN_DNS_SRV1=8.8.8.8
[ -z "$VPN_DNS_SRV2" ] && VPN_DNS_SRV2=8.8.4.4

# Validate protocol
case "$VPN_PROTO" in
  tcp|udp) ;;
  *) exiterr "VPN_PROTO must be 'tcp' or 'udp'. Got: '$VPN_PROTO'." ;;
esac

# Validate port
if ! printf '%s' "$VPN_PORT" | grep -Eq '^[0-9]+$' \
  || [ "$VPN_PORT" -lt 1 ] || [ "$VPN_PORT" -gt 65535 ]; then
  exiterr "VPN_PORT must be an integer between 1 and 65535."
fi

# Sanitize and validate client name
VPN_CLIENT_NAME=$(printf '%s' "$VPN_CLIENT_NAME" | \
  sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g')
if [ -z "$VPN_CLIENT_NAME" ]; then
  exiterr "VPN_CLIENT_NAME is invalid. Use one word only, no special characters except '-' and '_'."
fi

# Validate DNS servers
if [ -n "$VPN_DNS_SRV1" ] && ! check_ip "$VPN_DNS_SRV1"; then
  exiterr "VPN_DNS_SRV1 '$VPN_DNS_SRV1' is not a valid IPv4 address."
fi
if [ -n "$VPN_DNS_SRV2" ] && ! check_ip "$VPN_DNS_SRV2"; then
  exiterr "VPN_DNS_SRV2 '$VPN_DNS_SRV2' is not a valid IPv4 address."
fi

# Determine server address for client configurations
if [ -n "$VPN_DNS_NAME" ]; then
  if ! check_dns_name "$VPN_DNS_NAME"; then
    exiterr "VPN_DNS_NAME '$VPN_DNS_NAME' is not a valid fully qualified domain name (FQDN)."
  fi
  server_addr="$VPN_DNS_NAME"
elif [ -n "$VPN_PUBLIC_IP" ]; then
  if ! check_ip "$VPN_PUBLIC_IP"; then
    exiterr "VPN_PUBLIC_IP '$VPN_PUBLIC_IP' is not a valid IPv4 address."
  fi
  server_addr="$VPN_PUBLIC_IP"
else
  echo
  echo "Trying to auto-detect public IP of this server..."
  public_ip=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(wget -t 2 -T 10 -qO- http://ipv4.icanhazip.com 2>/dev/null)
  check_ip "$public_ip" || public_ip=$(wget -t 2 -T 10 -qO- http://ip1.dynupdate.no-ip.com 2>/dev/null)
  if ! check_ip "$public_ip"; then
    exiterr "Cannot detect this server's public IP. Define it in your 'env' file as 'VPN_PUBLIC_IP'."
  fi
  server_addr="$public_ip"
fi

mkdir -p /etc/openvpn/server/easy-rsa
mkdir -p /etc/openvpn/clients

OVPN_CONF="/etc/openvpn/server/server.conf"

echo
echo "OpenVPN Docker - https://github.com/hwdsl2/docker-openvpn"

if ! grep -q " /etc/openvpn " /proc/mounts; then
  echo
  echo "Note: /etc/openvpn is not mounted. Server data (keys, certificates"
  echo "      and client configs) will be lost on container removal."
  echo "      Mount a Docker volume at /etc/openvpn to persist data."
fi

if [ ! -f "$OVPN_CONF" ]; then
  echo
  echo "Starting OpenVPN setup..."
  echo "Server address: $server_addr"
  echo "Protocol: $VPN_PROTO, Port: $VPN_PORT"
  echo "First client: $VPN_CLIENT_NAME"
  echo "DNS servers: $VPN_DNS_SRV1, $VPN_DNS_SRV2"
  echo

  echo "Initializing PKI..."
  export EASYRSA_PKI="/etc/openvpn/server/easy-rsa/pki"
  easyrsa_run --batch init-pki
  easyrsa_run --batch build-ca nopass
  easyrsa_run --batch --days=3650 build-server-full server nopass
  easyrsa_run --batch --days=3650 build-client-full "$VPN_CLIENT_NAME" nopass
  easyrsa_run --batch --days=3650 gen-crl

  # Copy certs to server directory
  cp /etc/openvpn/server/easy-rsa/pki/ca.crt \
     /etc/openvpn/server/easy-rsa/pki/private/ca.key \
     /etc/openvpn/server/easy-rsa/pki/issued/server.crt \
     /etc/openvpn/server/easy-rsa/pki/private/server.key \
     /etc/openvpn/server/easy-rsa/pki/crl.pem \
     /etc/openvpn/server/
  # CRL is read with each client connection (OpenVPN drops to nobody)
  chown nobody:nobody /etc/openvpn/server/crl.pem
  # Without +x on the directory, OpenVPN can't run stat() on the CRL file
  chmod o+x /etc/openvpn/server/

  # Generate TLS crypt key
  openvpn --genkey secret /etc/openvpn/server/tc.key

  # Use pre-defined ffdhe2048 DH parameters (RFC 7919)
  cat > /etc/openvpn/server/dh.pem <<'DHEOF'
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----
DHEOF

  # Generate server configuration
  cat > /etc/openvpn/server/server.conf <<EOF
port $VPN_PORT
proto $VPN_PROTO
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA256
tls-crypt tc.key
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $VPN_DNS_SRV1"
push "dhcp-option DNS $VPN_DNS_SRV2"
push "block-outside-dns"
push "block-ipv6"
ifconfig-pool-persist ipp.txt
keepalive 10 120
cipher AES-128-GCM
user nobody
group nobody
persist-key
persist-tun
verb 3
crl-verify crl.pem
EOF
  if [ "$VPN_PROTO" = "udp" ]; then
    echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
  fi

  # Generate client config template
  cat > /etc/openvpn/server/client-common.txt <<EOF
client
dev tun
proto $VPN_PROTO
remote $server_addr $VPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-128-GCM
ignore-unknown-option block-outside-dns block-ipv6
verb 3
EOF

  # Generate first client .ovpn file
  {
    cat /etc/openvpn/server/client-common.txt
    echo "<ca>"
    cat /etc/openvpn/server/easy-rsa/pki/ca.crt
    echo "</ca>"
    echo "<cert>"
    sed -ne '/BEGIN CERTIFICATE/,$ p' \
      /etc/openvpn/server/easy-rsa/pki/issued/"$VPN_CLIENT_NAME".crt
    echo "</cert>"
    echo "<key>"
    cat /etc/openvpn/server/easy-rsa/pki/private/"$VPN_CLIENT_NAME".key
    echo "</key>"
    echo "<tls-crypt>"
    sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
    echo "</tls-crypt>"
  } > /etc/openvpn/clients/"$VPN_CLIENT_NAME".ovpn
  chmod 600 /etc/openvpn/clients/"$VPN_CLIENT_NAME".ovpn

  echo
  echo "Setup complete."
  echo "Client configuration: /etc/openvpn/clients/$VPN_CLIENT_NAME.ovpn"
  echo "Use 'docker cp <container>:/etc/openvpn/clients/$VPN_CLIENT_NAME.ovpn .' to download it."
  echo "Use 'docker exec <container> ovpn_manage --addclient <name>' to add more clients."
  echo
else
  echo
  echo "Found existing OpenVPN configuration, starting server..."
  echo
  # Refresh CRL symlink ownership in case volume was remounted
  chown nobody:nobody /etc/openvpn/server/crl.pem 2>/dev/null || true
  chmod o+x /etc/openvpn/server/ 2>/dev/null || true
fi

# Update sysctl settings
syt='/sbin/sysctl -e -q -w'
$syt net.ipv4.ip_forward=1 2>/dev/null
$syt net.ipv4.conf.all.accept_redirects=0 2>/dev/null
$syt net.ipv4.conf.all.send_redirects=0 2>/dev/null
$syt net.ipv4.conf.all.rp_filter=0 2>/dev/null
$syt net.ipv4.conf.default.accept_redirects=0 2>/dev/null
$syt net.ipv4.conf.default.send_redirects=0 2>/dev/null
$syt net.ipv4.conf.default.rp_filter=0 2>/dev/null
$syt "net.ipv4.conf.$NET_IFACE.send_redirects=0" 2>/dev/null
$syt "net.ipv4.conf.$NET_IFACE.rp_filter=0" 2>/dev/null

# Set up iptables rules
modprobe -q ip_tables 2>/dev/null
if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$NET_IFACE" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$NET_IFACE" -j MASQUERADE
  iptables -I INPUT -p "$VPN_PROTO" --dport "$VPN_PORT" -j ACCEPT
  iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
  iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
fi

echo "Starting OpenVPN server..."
echo
exec openvpn --cd /etc/openvpn/server --config server.conf
