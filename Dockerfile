# Dockerfile for icinga
FROM ubuntu:wily

ENV DEBIAN_FRONTEND noninteractive 

# Basic installs
RUN echo "deb http://archive.ubuntu.com/ubuntu/ wily multiverse" >> /etc/apt/sources.list \
 && echo "deb http://archive.ubuntu.com/ubuntu/ wily-updates multiverse" >> /etc/apt/sources.list \
 && echo "deb http://archive.ubuntu.com/ubuntu/ wily-security multiverse" >> /etc/apt/sources.list \
 && sed -i -e 's/^deb-src.*/#&/' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends apt-utils vim unzip curl patch gzip pwgen python dnsutils build-essential \
                                               autoconf mrtg cron \
 && apt-get install -y --no-install-recommends mysql-server php5 php5-cli php5-mysql php5-ssh2 php5-curl apache2 \
                                               mysql-client snmp-mibs-downloader freeipmi libipc-run-perl libswitch-perl \
                                               libnumber-format-perl libconfig-inifiles-perl libdatetime-perl \
 && php5enmod -s ALL ssh2 curl \
 && mkdir -p /var/www/mrtg \
 && /usr/bin/mysql_install_db --user=mysql --ldata=/var/lib/mysql \
 && /bin/sh -c "cd /usr ; /usr/bin/mysqld_safe > /dev/null 2>&1 &" \
 && sleep 5 \
 && apt-get install -y --no-install-recommends icinga icinga-idoutils icinga-doc nagios-plugins nagios-images nagios-snmp-plugins nagios-plugins-contrib snmp\
 && apt-get install -y --no-install-recommends icinga-web icinga-web-config-icinga icinga-web-pnp \
 && apt-get install -y --no-install-recommends pnp4nagios pnp4nagios-web-config-icinga pnp4nagios-web \
 && killall mysqld

# Minor changes and install MIBs
RUN chmod g+xs /var/lib/icinga/rw \
 && chmod u+s /usr/lib/nagios/plugins/check_dhcp \
 && cp /usr/share/doc/snmp-mibs-downloader/examples/cisco* /etc/snmp-mibs-downloader/ \
 && cd /etc/snmp-mibs-downloader && gzip -d ciscolist.gz \
 && sed -i -e '/CISCO-802-TAP-MIB/d;/CISCO-IP-TAP-CAPABILITY/d;/CISCO-IP-TAP-MIB/d;/CISCO-SYS-INFO-LOG-MIB/d;/CISCO-TAP2-CAPABILITY/d;/CISCO-TAP2-MIB/d;/CISCO-TAP-MIB/d;/CISCO-USER-CONNECTION-TAP-MIB/d;/CISCO-IP-CAPABILITY/d' /etc/snmp-mibs-downloader/ciscolist \
 && sed -i -e '/^AUTOLOAD=.*/ s/iana"/iana cisco"/' /etc/snmp-mibs-downloader/snmp-mibs-downloader.conf \
 && echo "ARCHDIR=auto/mibs/v2" >> /etc/snmp-mibs-downloader/cisco.conf \
 && download-mibs \
 && curl -kL https://downloads.dell.com/FOLDER03857069M/1/PC6200v3.3.15.1a40.zip -o tmp.zip \
 && unzip -j tmp.zip '*MIBs.zip' \
 && rm -f tmp.zip \
 && mkdir -p /usr/share/snmp/mibs/PC6200 \
 && unzip -d /usr/share/snmp/mibs/PC6200/ `ls *MIBs.zip` \
 && rm -f *MIBs.zip \
 && sed -i -e '/^mibs :$/i mibdirs +/usr/share/snmp/mibs/PC6200\nmibdirs +/var/lib/mibs/cisco' /etc/snmp/snmp.conf \
 && apt-get clean

# Setup idoutils and icinga-web
RUN htpasswd -bc /etc/icinga/htpasswd.users root password \
 && sed -i -e '/ssh/,/}/s/members *localhost/#&/' /etc/icinga/objects/hostgroups_icinga.cfg \
 && usermod -a -G nagios www-data \
 && sed -i -e 's/IDO2DB=no/IDO2DB=yes/' /etc/default/icinga \
 && sed -i -e 's/check_external_commands=0/check_external_commands=1/' /etc/icinga/icinga.cfg \
 && sed -i -e 's/icingaadmin/root/' /etc/icinga/cgi.cfg \
 && cp /usr/share/doc/icinga-idoutils/examples/idoutils.cfg-sample /etc/icinga/modules/idoutils.cfg

# Install nagiosql
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
 && sed -i -e "s/^;date.timezone =$/date.timezone = \"Etc\/GMT\"/" /etc/php5/apache2/php.ini

# Setup nagiosql
COPY import.sql /tmp/
COPY nagiosql /etc/nagiosql
RUN /bin/sh -c "cd /usr ; /usr/bin/mysqld_safe > /dev/null 2>&1 &" \
 && sleep 15 \
 && mysql -uroot -e "CREATE DATABASE IF NOT EXISTS db_nagiosql_v32; GRANT ALL ON db_nagiosql_v32.* TO nagiosql_user@localhost IDENTIFIED BY 'nagiosql_pass';" \
 && mysql -uroot db_nagiosql_v32 < /var/www/html/nagiosql32/install/sql/nagiosQL_v32_db_mysql.sql \
 && mysql -uroot db_nagiosql_v32 < /tmp/import.sql \
 && echo mysql -uroot db_nagiosql_v32 -e "INSERT INTO tbl_user VALUES (1,'root','Administrator',MD5('password'),'1','0','1','1','1',1,'0000-00-00 00:00:00',NOW());" \
 && mysql -uroot db_nagiosql_v32 -e "INSERT INTO tbl_settings VALUES \
         (1,'db','version','3.2.0'), \
         (2,'db','type','mysql'), \
         (3,'path','protocol','http'), \
         (4,'path','tempdir','/tmp'), \
         (5,'path','base_url','/nagiosql32/'), \
         (6,'path','base_path','/var/www/html/nagiosql32/'), \
         (7,'data','locale','en_GB'), \
         (8,'data','encoding','utf-8'), \
         (9,'security','logofftime','3600'), \
         (10,'security','wsauth','0'), \
         (11,'common','pagelines','15'), \
         (12,'common','seldisable','1'), \
         (13,'common','tplcheck','0'), \
         (14,'common','updcheck','1'), \
         (15,'network','proxy','0'), \
         (16,'network','proxyserver',''), \
         (17,'network','proxyuser',''), \
         (18,'network','proxypasswd',''), \
         (19,'network','onlineupdate','0');" \
 && mysql -uroot db_nagiosql_v32 -e "UPDATE tbl_configtarget SET \
         basedir='/etc/nagiosql/', \
         hostconfig='/etc/nagiosql/objects/', \
         serviceconfig='/etc/nagiosql/objects/', \
         backupdir='/etc/nagiosql/backup/', \
         hostbackup='/etc/nagiosql/backup/', \
         servicebackup='/etc/nagiosql/backup/', \
         nagiosbasedir='/etc/icinga/', \
         importdir='/etc/nagios-plugins/config/', \
         picturedir='/usr/share/nagios/htdocs/images/logos/', \
         commandfile='/var/lib/icinga/rw/icinga.cmd', \
         binaryfile='/usr/sbin/icinga', \
         pidfile='/var/run/icinga/icinga.pid', \
         conffile='/etc/icinga/icinga.cfg', \
         last_modified=NOW() WHERE id=1;" \
 && killall mysqld \
 && mkdir -p /etc/nagiosql/objects /etc/nagiosql/backup \
 && chown -R www-data:www-data /etc/nagiosql \
 && chmod -R g+rs /etc/nagiosql \
 && chmod u+s /usr/sbin/icinga \
 && sed -i -e "s/^cfg_file=\/etc\/icinga\/commands.cfg/#&/" /etc/icinga/icinga.cfg \
 && sed -i -e "s/^cfg_dir=\/etc\/nagios-plugins\/config/#&/" /etc/icinga/icinga.cfg \
 && sed -i -e "s/^cfg_dir=\/etc\/icinga\/objects/cfg_dir=\/etc\/nagiosql/" /etc/icinga/icinga.cfg \
 && rm -rf /var/www/html/nagiosql32/install

ADD settings.php /var/www/html/nagiosql32/config/settings.php

RUN curl -L 'http://edcint.co.nz/checkwmiplus/wmi-1.3.14.tar.gz' | tar -xz -C tmp -f - \
 && cd tmp/wmi-1.3.14 && sed -i -e '583d' Samba/source/pidl/pidl \
 && ulimit -n 8192 && make "CPP=gcc -E -ffreestanding" \
 && cd ../.. && rm -rf tmp/wmi-1.3.14

RUN chown www-data:www-data /var/www/html/nagiosql32/config/settings.php \
 && curl -kL 'https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=3928&cf_id=24' -o /usr/lib/nagios/plugins/check_mrtgtraf.pl \
 && chmod 0755 /usr/lib/nagios/plugins/check_mrtgtraf.pl \
 && sed -i -e '/^use lib .*/ s/".*"/"\/usr\/lib\/nagios\/plugins\/utils.pm"/' /usr/lib/nagios/plugins/check_mrtgtraf.pl \
 && curl -kL 'https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=464&cf_id=24' -o /usr/lib/nagios/plugins/check_all_interfaces.pl \
 && chmod 0755 /usr/lib/nagios/plugins/check_all_interfaces.pl \
 && mkdir -p /var/cache/nagios/iferrors && chown nagios:nagios /var/cache/nagios/iferrors \
 && curl -kL 'https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=5964&cf_id=24' -o /usr/lib/nagios/plugins/check_liebert.py \
 && chmod 0755 /usr/lib/nagios/plugins/check_liebert.py \
 && curl -kL 'https://exchange.nagios.org/components/com_mtree/attachment.php?link_id=4136&cf_id=24' -o /usr/lib/nagios/plugins/check_apc.pl \
 && chmod 0755 /usr/lib/nagios/plugins/check_apc.pl \
 && curl -L 'http://edcint.co.nz/checkwmiplus/sites/default/files/check_wmi_plus.v1.62.tar.gz' | tar -xz -C /usr/lib/nagios/plugins -f - \
 && mv /usr/lib/nagios/plugins/etc/check_wmi_plus /etc/ \
 && mv /etc/check_wmi_plus/check_wmi_plus.conf.sample /etc/check_wmi_plus/check_wmi_plus.conf \
 && sed -i -e '/^\$base_dir=.*/ s/=.*/="\/usr\/lib\/nagios\/plugins"\;/; /^\$wmic_command=.*/ s/=.*/="\/bin\/wmic"\;/' /etc/check_wmi_plus/check_wmi_plus.conf \
 && rmdir /usr/lib/nagios/plugins/etc

ADD startup.sh /usr/sbin/startup.sh
CMD startup.sh

