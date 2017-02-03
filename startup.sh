#!/usr/bin/env bash
set -euf -o pipefail

/bin/sh -c "/usr/bin/mysqld_safe > /dev/null 2>&1 &"

sleep 5

apache2ctl start

/bin/sh -c "/usr/sbin/ido2db -c /etc/icinga/ido2db.cfg"

/usr/sbin/icinga /etc/icinga/icinga.cfg

