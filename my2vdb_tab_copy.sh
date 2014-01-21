#!/bin/bash

# Variables (need to be changed to options before production use)

myHost="mm3.propellerads.com"
myDb="openx"
myTable="conversions"
sshCmd="/usr/bin/ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no"

vdbHost="vdb1"
vdbDb="openx"
vdbUser="dbadmin"
vdbPass="YGtQaRSdGrVe1g"

 #${sshCmd} ${myHost} sudo mkdir -p /root/tmp
 #${sshCmd} ${myHost} sudo rm -f /root/tmp/*
 #${sshCmd} ${myHost} sudo chown -R mysql:mysql /root/tmp
 #echo "mysqldump --lock-tables=false --compatible=postgresql --fields-terminated-by=,  --fields-enclosed-by=\\\" --tab='/root/tmp' ${myDb} ${myTable}"|${sshCmd} ${myHost} sudo bash

#${sshCmd} ${myHost} sudo bash < ./prepare.sh

#${sshCmd} ${vdbHost} sudo chmod -R 777 /home/dbadmin/tmp/
#scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${myHost}:/root/tmp/*.prep ./
#scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no ./*.prep ${vdbHost}:/home/dbadmin/tmp/
#${sshCmd} ${vdbHost} sudo chmod -R 777 /home/dbadmin/tmp/

if [[ "$1" == "force" ]]; then
    echo "== DROP TABLE (with force arg)"
    echo -e "DROP TABLE IF EXISTS openx.${myTable} CASCADE;\n \i /home/dbadmin/tmp/${myTable}.sql.prep"|${sshCmd} ${vdbHost} /opt/vertica/bin/vsql -w${vdbPass} -d ${vdbDb} -U ${vdbUser}
fi
xsize=$(echo ls -la /root/tmp/conversions.txt |awk '{ print $5 }'|${sshCmd} ${myHost} sudo bash)
echo "== Piped COPY to VDB:"
echo "cat /root/tmp/conversions.txt | pv -pterab -s ${xsize}| pigz -4 -p 6 | PGPASSWORD=${vdbPass} psql -w -d ${vdbDb} -U ${vdbUser} -p 5433 -h vdb1.propellerads.com -c \"BEGIN; DELETE FROM openx.conversions; COPY openx.conversions FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT;\"" | ${sshCmd} ${myHost} sudo bash




