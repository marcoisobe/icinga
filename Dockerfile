#Dockerfile for icinga
FROM ubuntu:wily

ENV DEBIAN_FRONTEND noninteractive 

RUN apt-get update \
 && apt-get install -y --no-install-recommends apt-utils vim unzip curl \
 && apt-get install -y --no-install-recommends mysql-server php5 php5-cli php5-mysql php5-ssh2 php5-curl apache2 mysql-client \
 && php5enmod -s ALL ssh2 curl \
 && /usr/bin/mysql_install_db --user=mysql --ldata=/var/lib/mysql \
 && /bin/sh -c "cd /usr ; /usr/bin/mysqld_safe > /dev/null 2>&1 &" \
 && sleep 5 \
 && apt-get install -y --no-install-recommends icinga icinga-idoutils icinga-doc nagios-plugins nagios-images \
 && apt-get install -y --no-install-recommends icinga-web icinga-web-config-icinga icinga-web-pnp \
 && apt-get install -y --no-install-recommends pnp4nagios pnp4nagios-web-config-icinga pnp4nagios-web \
 && killall mysqld \
 && apt-get clean

RUN htpasswd -bc /etc/icinga/htpasswd.users root password \
 && sed -ie '/ssh/,/}/s/members *localhost/#&/' /etc/icinga/objects/hostgroups_icinga.cfg \
 && usermod -a -G nagios www-data \
 && sed -ie 's/IDO2DB=no/IDO2DB=yes/' /etc/default/icinga \
 && cp /usr/share/doc/icinga-idoutils/examples/idoutils.cfg-sample /etc/icinga/modules/idoutils.cfg

RUN curl -kL -o tmp.zip https://sourceforge.net/projects/nagiosql/files/nagiosql/NagiosQL%203.2.0/nagiosql_320.zip/download \
 && unzip -d /var/www/html/ tmp.zip \
 && rm -f tmp.zip \
 && curl -kL -o tmp.zip https://sourceforge.net/projects/nagiosql/files/nagiosql/NagiosQL%203.2.0/nagiosql_320_service_pack_1_additional_fixes_only.zip/download \
 && unzip -d /tmp/ tmp.zip \
 && rm -f tmp.zip \
 && curl -kL -o tmp.zip https://sourceforge.net/projects/nagiosql/files/nagiosql/NagiosQL%203.2.0/nagiosql_320_service_pack_2_additional_fixes_only.zip/download \
 && unzip -d /tmp/ tmp.zip \
 && rm -f tmp.zip \
 && cp -r /tmp/NagiosQL_3.2.0_SP1/* /var/www/html/nagiosql32/ \
 && cp -r /tmp/NagiosQL_3.2.0_SP2/* /var/www/html/nagiosql32/ \
 && rm -rf /tmp/NagiosQL_3.2.0_SP1 /tmp/NagiosQL_3.2.0_SP2 \
 && chown -R www-data:www-data /var/www/html/nagiosql32 \
 && sed -ie "s/^;date.timezone =$/date.timezone = \"Etc\/GMT\"/" /etc/php5/apache2/php.ini \
 && /bin/sh -c "cd /usr ; /usr/bin/mysqld_safe > /dev/null 2>&1 &" \
 && sleep 5 \
 && echo "CREATE DATABASE IF NOT EXISTS db_nagiosql_v32;" | mysql -u root \
 && echo "GRANT ALL on db_nagiosql_v32.* TO nagiosql_user@localhost IDENTIFIED BY 'nagiosql_pass';" | mysql -u root \
 && mysql -uroot db_nagiosql_v32 < /var/www/html/nagiosql32/install/sql/nagiosQL_v32_db_mysql.sql \
 && echo "INSERT INTO tbl_user VALUES (1,'root','Administrator',MD5('password'),'1','0','1','1','1',1,'0000-00-00 00:00:00',NOW());" | mysql -uroot db_nagiosql_v32 \
 && echo "INSERT INTO tbl_settings VALUES (1,'db','version','3.2.0'),(2,'db','type','mysql'),(3,'path','protocol','http'),(4,'path','tempdir','/tmp'),(5,'path','base_url','/nagiosql32/'),(6,'path','base_path','/var/www/html/nagiosql32/'),(7,'data','locale','en_GB'),(8,'data','encoding','utf-8'),(9,'security','logofftime','3600'),(10,'security','wsauth','0'),(11,'common','pagelines','15'),(12,'common','seldisable','1'),(13,'common','tplcheck','0'),(14,'common','updcheck','1'),(15,'network','proxy','0'),(16,'network','proxyserver',''),(17,'network','proxyuser',''),(18,'network','proxypasswd',''),(19,'network','onlineupdate','0');" | mysql -uroot db_nagiosql_v32 \
 && killall mysqld \
 && mkdir /etc/nagiosql \
 && chown www-data:www-data /etc/nagiosql \
 && rm -rf /var/www/html/nagiosql32/install

ADD settings.php /var/www/html/nagiosql32/config/settings.php

RUN chown www-data:www-data /var/www/html/nagiosql32/config/settings.php

ADD startup.sh /usr/sbin/startup.sh
CMD startup.sh

