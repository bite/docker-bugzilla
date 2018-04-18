#!/bin/bash

cd $BUGZILLA_ROOT

# Configure database
service mysql start
sleep 5
mysql -e "GRANT ALL PRIVILEGES ON *.* TO bugs@localhost IDENTIFIED BY 'bugs'; FLUSH PRIVILEGES;"
mysql -e "CREATE DATABASE bugs CHARACTER SET = 'utf8';"

perl checksetup.pl /checksetup_answers.txt
perl checksetup.pl /checksetup_answers.txt

mysqladmin -u root shutdown
