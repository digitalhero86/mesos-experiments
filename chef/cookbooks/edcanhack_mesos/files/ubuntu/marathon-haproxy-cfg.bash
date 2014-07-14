#!/bin/bash
set -o errexit -o nounset -o pipefail
function -h {
cat <<\USAGE
 USAGE: haproxy_cfg <marathon host:port>

haproxy_cfg generates a config file to run HAProxy on localhost and proxy to a number of backend hosts.

To gracefully reload haproxy:

:; haproxy -f /path/to/config -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)

USAGE
}; function --help { -h ;}
export LC_ALL=en_US.UTF-8

function header {
  cat <<EOF
global
  daemon
  log 127.0.0.1 local0
  log 127.0.0.1 local1 notice
  maxconn 4096

defaults
  log         global
  retries     3
  maxconn     2000
  contimeout  5000
  clitimeout  50000
  srvtimeout  50000

listen stats
  bind 127.0.0.1:9090
  balance
  mode http
  stats enable
  stats auth admin:admin
EOF
}

function apps {
  curl -s "$1/v1/endpoints" | while read -r line
  do
    set -- $line
    local app_name="$1"
    local app_port="$2"
    shift 2
    cat <<EOF

listen $app_name
  bind 127.0.0.1:$app_port
  mode http
  option tcplog
  option httpchk GET /
  balance leastconn
EOF
    while [[ $# -ne 0 ]]
    do
      out "  server ${app_name}-$# $1 check"
      shift
    done
  done
}

function config {
  header
  apps "$@"
}

function main {
  config "$@"
}

function msg { out "$*" >&2 ;}
function err { local x=$? ; msg "$*" ; return $(( $x == 0 ? 1 : $x )) ;}
function out { printf '%s\n' "$*" ;}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi