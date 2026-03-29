#!/bin/bash
#
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
export EASYRSA_PKI="/etc/openvpn/server/easy-rsa/pki"

exiterr()    { echo "Error: $1" >&2; exit 1; }
easyrsa_run() { echo "+ easyrsa $*" >&2; easyrsa "$@" >/dev/null 2>&1; }

show_usage() {
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  cat 1>&2 <<'EOF'

OpenVPN Docker - Client Management
https://github.com/hwdsl2/docker-openvpn

Usage: docker exec <container> ovpn_manage [options]

Options:
  --addclient    [client name]   add a new client
  --exportclient [client name]   export configuration for an existing client
  --listclients                  list the names of existing clients
  --revokeclient [client name]   revoke an existing client
  -y, --yes                      assume "yes" when revoking a client
  -h, --help                     show this help message and exit

EOF
  exit 1
}

check_container() {
  if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
    && [ -z "$KUBERNETES_SERVICE_HOST" ] \
    && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
    exiterr "This script must be run inside a container (e.g. Docker, Podman)."
  fi
}

check_setup() {
  if [ ! -f /etc/openvpn/server/server.conf ]; then
    exiterr "OpenVPN has not been set up yet. Please start the container first."
  fi
}

set_client_name() {
  client=$(printf '%s' "$unsanitized_client" | \
    sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g')
}

parse_args() {
  add_client=0
  export_client=0
  list_clients=0
  revoke_client=0
  assume_yes=0
  unsanitized_client=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --addclient)
        add_client=1
        unsanitized_client="$2"
        shift; shift
        ;;
      --exportclient)
        export_client=1
        unsanitized_client="$2"
        shift; shift
        ;;
      --listclients)
        list_clients=1
        shift
        ;;
      --revokeclient)
        revoke_client=1
        unsanitized_client="$2"
        shift; shift
        ;;
      -y|--yes)
        assume_yes=1
        shift
        ;;
      -h|--help)
        show_usage
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done
}

check_args() {
  if [ "$((add_client + export_client + list_clients + revoke_client))" -eq 0 ]; then
    show_usage
  fi
  if [ "$((add_client + export_client + list_clients + revoke_client))" -gt 1 ]; then
    show_usage "Specify only one of '--addclient', '--exportclient', '--listclients' or '--revokeclient'."
  fi
  if [ "$((add_client + export_client + revoke_client))" -eq 1 ]; then
    set_client_name
    if [ -z "$client" ]; then
      exiterr "Invalid client name. Use one word only, no special characters except '-' and '_'."
    fi
  fi
  if [ "$add_client" = 1 ]; then
    if [ -f "$EASYRSA_PKI/issued/${client}.crt" ]; then
      exiterr "'$client': invalid name. Client already exists."
    fi
  fi
  if [ "$export_client" = 1 ] || [ "$revoke_client" = 1 ]; then
    if [ ! -f "$EASYRSA_PKI/issued/${client}.crt" ]; then
      exiterr "Invalid client name, or client does not exist."
    fi
  fi
}

gen_client_ovpn() {
  local c="$1"
  local ovpn_file="/etc/openvpn/clients/${c}.ovpn"
  mkdir -p /etc/openvpn/clients
  {
    cat /etc/openvpn/server/client-common.txt
    echo "<ca>"
    cat /etc/openvpn/server/easy-rsa/pki/ca.crt
    echo "</ca>"
    echo "<cert>"
    sed -ne '/BEGIN CERTIFICATE/,$ p' \
      /etc/openvpn/server/easy-rsa/pki/issued/"${c}".crt
    echo "</cert>"
    echo "<key>"
    cat /etc/openvpn/server/easy-rsa/pki/private/"${c}".key
    echo "</key>"
    echo "<tls-crypt>"
    sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
    echo "</tls-crypt>"
  } > "$ovpn_file"
  chmod 600 "$ovpn_file"
}

do_add_client() {
  echo
  echo "Adding client '$client'..."
  easyrsa_run --batch --days=3650 build-client-full "$client" nopass
  gen_client_ovpn "$client"
  echo
  echo "Client '$client' added. Config: /etc/openvpn/clients/$client.ovpn"
  echo "Use 'docker cp <container>:/etc/openvpn/clients/$client.ovpn .' to download it."
  echo
}

do_export_client() {
  gen_client_ovpn "$client"
  cat /etc/openvpn/clients/"$client".ovpn
}

do_list_clients() {
  echo
  echo "Checking for existing clients..."
  num=$(grep -c "^V" "$EASYRSA_PKI/index.txt" 2>/dev/null || echo 0)
  if [ "$num" -eq 0 ]; then
    echo
    echo "No clients found."
    echo
    exit 0
  fi
  echo
  grep "^V" "$EASYRSA_PKI/index.txt" | cut -d '=' -f 2 | nl -s ') '
  echo
  if [ "$num" -eq 1 ]; then
    printf '%s\n\n' "Total: 1 client"
  else
    printf '%s\n\n' "Total: $num clients"
  fi
}

do_revoke_client() {
  if [ "$assume_yes" != 1 ]; then
    echo
    printf 'Revoke client '"'"'%s'"'"'? This cannot be undone. [y/N]: ' "$client"
    read -r revoke
    case "$revoke" in
      [yY][eE][sS]|[yY]) ;;
      *) echo; echo "Revocation aborted."; echo; exit 1 ;;
    esac
  fi
  echo
  echo "Revoking client '$client'..."
  easyrsa_run --batch revoke "$client"
  easyrsa_run --batch --days=3650 gen-crl
  # Update the CRL used by the running OpenVPN server
  rm -f /etc/openvpn/server/crl.pem
  cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
  chown nobody:nobody /etc/openvpn/server/crl.pem
  # Remove the client .ovpn file if it exists
  rm -f /etc/openvpn/clients/"$client".ovpn
  echo
  echo "Client '$client' revoked."
  echo
}

check_container
check_setup
parse_args "$@"
check_args

if [ "$add_client" = 1 ]; then
  do_add_client
  exit 0
fi

if [ "$export_client" = 1 ]; then
  do_export_client
  exit 0
fi

if [ "$list_clients" = 1 ]; then
  do_list_clients
  exit 0
fi

if [ "$revoke_client" = 1 ]; then
  do_revoke_client
  exit 0
fi