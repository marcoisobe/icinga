#Dockerfile for icinga
FROM ubuntu:wily

ENV DEBIAN_FRONTEND noninteractive 

RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-utils vim \
 && apt-get install -y --no-install-recommends mysql-server php5 php5-cli php5-mysql apache2 mysql-client \
 && /usr/bin/mysql_install_db --user=mysql --ldata=/var/lib/mysql \
 && /bin/sh -c "cd /usr ; /usr/bin/mysqld_safe > /dev/null 2>&1 &" \
 && sleep 1 \
 && apt-get install -y --no-install-recommends icinga icinga-idoutils icinga-doc nagios-plugins nagios-images \
 && apt-get install -y --no-install-recommends icinga-web icinga-web-config-icinga icinga-web-pnp \
 && apt-get install -y --no-install-recommends pnp4nagios pnp4nagios-web-config-icinga pnp4nagios-web \
 && killall mysqld

RUN htpasswd -bc /etc/icinga/htpasswd.users icingaadmin icinga \
 && sed -ie '/ssh/,/}/s/members *localhost/#&/' /etc/icinga/objects/hostgroups_icinga.cfg \
 && usermod -a -G nagios www-data \
 && sed -ie 's/IDO2DB=no/IDO2DB=yes/' /etc/default/icinga \
 && cp /usr/share/doc/icinga-idoutils/examples/idoutils.cfg-sample /etc/icinga/modules/idoutils.cfg

ADD startup.sh /usr/sbin/startup.sh
CMD startup.sh

