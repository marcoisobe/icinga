#!/usr/bin/env bash

export ICINGAWEB_PASSWORD=${ICINGAWEB_PASSWORD:-$(pwgen -s 12 1)}
export IDO_PASSWORD=${IDO_PASSWORD:-$(pwgen -s 12 1)}
export NAGIOSQL_PASSWORD=${NAGIOSQL_PASSWORD:-$(pwgen -s 12 1)}

echo "*******************"
echo "* STARTING ICINGA *"
echo "*******************"

if [ -f /opt/pre_startup.sh ]; then
    chmod u+x /opt/pre_startup.sh
    echo "Found pre_startup.sh, executing it"
    /opt/pre_startup.sh
fi

chown -R mysql:mysql /var/lib/mysql

echo "Starting mysql"
/bin/sh -c "/usr/bin/mysqld_safe > /dev/null 2>&1 &"

sleep 15

echo "Setting icinga_web password to ${ICINGAWEB_PASSWORD}"
mysql -e "ALTER USER 'icinga_web'@'localhost' IDENTIFIED BY '${ICINGAWEB_PASSWORD}'; FLUSH PRIVILEGES;"
sed -i -e "s/dbc_dbpass='.*'/dbc_dbpass='${ICINGAWEB_PASSWORD}'/" /etc/dbconfig-common/icinga-web.conf
sed -i -e "s/mysql:\/\/icinga_web:.*@localhost/mysql:\/\/icinga_web:${ICINGAWEB_PASSWORD}@localhost/" /etc/icinga-web/conf.d/database-web.xml
echo "Clearing icinga-web cache"
/usr/lib/icinga-web/bin/clearcache.sh

echo "Setting icinga-idoutils password to ${IDO_PASSWORD}"
mysql -e "ALTER USER 'icinga-idoutils'@'localhost' IDENTIFIED BY '${IDO_PASSWORD}'; FLUSH PRIVILEGES;"
sed -i -e "s/dbc_dbpass='.*'/dbc_dbpass='${IDO_PASSWORD}'/" /etc/dbconfig-common/icinga-idoutils.conf
sed -i -e "s/mysql:\/\/icinga-idoutils:.*@localhost/mysql:\/\/icinga-idoutils:${IDO_PASSWORD}@localhost/" /etc/icinga-web/conf.d/database-ido.xml
sed -i -e "s/db_pass=.*/db_pass=${IDO_PASSWORD}/" /etc/icinga/ido2db.cfg

echo "Setting nagiosql_user password to ${NAGIOSQL_PASSWORD}"
mysql -e "ALTER USER 'nagiosql_user'@'localhost' IDENTIFIED BY '${NAGIOSQL_PASSWORD}'; FLUSH PRIVILEGES;"
sed -i -e "s/password *= .*/password     = ${NAGIOSQL_PASSWORD}/" /var/www/html/nagiosql32/config/settings.php

echo "Starting cron"
cron

echo "Starting apache"
apache2ctl start

echo "Starting ido2db"
/bin/sh -c "/usr/sbin/ido2db -c /etc/icinga/ido2db.cfg"

echo "Starting icinga"
/usr/sbin/icinga -d /etc/icinga/icinga.cfg
sleep 5

chown -R nagios:nagios /var/lib/pnp4nagios/perfdata

if [ -f /opt/post_startup.sh ]; then
    chmod u+x /opt/post_startup.sh
    echo "Found post_startup.sh, executing it"
    /opt/post_startup.sh
fi

tail -f /var/log/icinga/icinga.log

killall icinga

