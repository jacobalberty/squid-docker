#!/usr/bin/env bash
if [ -f "/run/squid.pid" ]; then
  # Clean up squid pid file
  rm -f /run/squid.pid
fi

if [[ "$1" == "squid" ]]; then
  shift;
  /usr/sbin/squid ${@}
else
  exec ${@}
fi

