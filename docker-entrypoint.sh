#!/usr/bin/env bash
if [ -f "/var/run/squid.pid" ]; then
  # Clean up squid pid file
  rm -f /var/run/squid.pid
fi

if [[ "$1" == "squid" ]]; then
  shift;
  /usr/sbin/squid ${@}
else
  exec ${@}
fi

