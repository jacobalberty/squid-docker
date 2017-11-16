#!/usr/bin/env bash
if [[ "$1" == "squid" ]]; then
    shift;
    /usr/sbin/squid ${@}
else
    exec ${@}
fi

