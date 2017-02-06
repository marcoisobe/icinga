<?php
exit;
?>
;///////////////////////////////////////////////////////////////////////////////
;
; NagiosQL
;
;///////////////////////////////////////////////////////////////////////////////
;
; Project  : NagiosQL
; Component: Database Configuration
; Website  : http://www.nagiosql.org
; Date     : February 6, 2017, 4:10 pm
; Version  : 3.2.0
;
;///////////////////////////////////////////////////////////////////////////////
[db]
type         = mysql
server       = localhost
port         = 3306
database     = db_nagiosql_v32
username     = nagiosql_user
password     = nagiosql_pass
[path]
base_url     = /nagiosql32/
base_path    = /var/www/html/nagiosql32/
