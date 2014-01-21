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

ncport="8867"
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
echo "== Listen on ${ncport} port on ${myHost}..."
echo "cat /root/tmp/conversions.txt | pigz -4 -p 6 |nc -d -l ${ncport} &"|${sshCmd} ${myHost} sudo bash &
xsize=$(echo ls -la /root/tmp/conversions.txt |awk '{ print $5 }'|${sshCmd} ${myHost} sudo bash)
echo "== Piped COPY to VDB:"
${sshCmd} ${myHost} sudo bash < ./nc.sh




