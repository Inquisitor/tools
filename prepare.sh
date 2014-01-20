#!/bin/bash

cat /root/tmp/conversions.sql |perl -pe 's/\S*int\(\d+\)/int/g' |gsed -e "s/enum('t','f')/boolean/ig" -e 's/UNIQUE KEY/KEY/ig' -e 's/PRIMARY KEY/KEY/ig' -e 's/unsigned//g' -e 's/ text/ varchar(65000)/ig' -e 's/ double / float /ig' | perl -pe 's/CHARACTER SET \w+ //ig' | perl -pe 's/ enum\(\S+\) / varchar(16) /g' | grep -Fv '/*!' | grep -v '^DROP ' | perl -pe 's/ float(\S+)/ float/g' | perl -pe 's/COMMENT .*,\s*$/,/ig' | grep -v '^USE ' | grep -v '^\s*KEY ' | perl -pe 's/,\s*\n\);/);/gs' > /root/tmp/conversions.sql.prep

gsed -i 's/"//g' /root/tmp/conversions.sql.prep
gsed -i 's/\(CREATE TABLE\) \([a-z_]*\)/\1 openx\.\2/' /root/tmp/conversions.sql.prep
gsed -i 's/^--.*//' /root/tmp/conversions.sql.prep
gsed -i "s/NOT NULL DEFAULT '0000-00-00'/DEFAULT NULL/" /root/tmp/conversions.sql.prep
gsed -i "s/NOT NULL DEFAULT '0000-00-00 00:00:00'/DEFAULT NULL/" /root/tmp/conversions.sql.prep
gsed -i "s/date DEFAULT '0000-00-00'/date DEFAULT NULL/ig" /root/tmp/conversions.sql.prep
gsed -i "s/date NOT NULL/date DEFAULT NULL/g" /root/tmp/conversions.sql.prep
gsed -i "s/ KEY.*//" /root/tmp/conversions.sql.prep
gsed -i '/^$/d' /root/tmp/conversions.sql.prep
gsed -i '/^ *$/d' /root/tmp/conversions.sql.prep
gsed -i "N;/)\;/s/,\n/\n/;P;D;" /root/tmp/conversions.sql.prep
gsed -i "s/unique int  NOT NULL/\"unique\" int  NOT NULL/" /root/tmp/conversions.sql.prep
gsed -i -e "s/desc varchar(65000) NOT NULL/\"desc\" varchar(65000) NOT NULL/" -e "s/double(8,4)/DOUBLE PRECISION/g" /root/tmp/conversions.sql.prep
gsed -i "s/ enum('new','accepted','in discussion','exist','declined by us','refugsed by adv','active','disappeared','pending')/ VARCHAR(20)/g" /root/tmp/conversions.sql.prep
gsed -i "s/datetime NOT NULL/datetime DEFAULT NULL/g" /root/tmp/conversions.sql.prep
gsed -i "s/timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP/timestamp DEFAULT CURRENT_TIMESTAMP/g" /root/tmp/conversions.sql.prep
gsed -i "s/ bit(1)/ BINARY/g" /root/tmp/conversions.sql.prep
gsed -i -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' /root/tmp/conversions.txt
