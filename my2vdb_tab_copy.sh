#!/bin/bash

# Variables (need to be changed to options before production use)

#myHost="mm3.propellerads.com"
#myDb="openx"
#myUser="openx"
#myPass="bd4MYpJHq"
#myTable="conversions"
#sshCmd="/usr/bin/ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no"

#vdbHost="vdb1"
#vdbDb="openx"
#vdbUser="dbadmin"
#vdbPass="YGtQaRSdGrVe1g"
force=0
debug=0

### Parse command line arguments

while [[ "$#" -gt "0" ]];
    do
        case "$1" in
            -mh | --mysql-host ) myHost="$2"; shift 2;;
            -md | --mysql-database ) myDb="$2"; shift 2;;
            -mu | --mysql-user ) myUser="$2"; shift 2;;
            -mp | --mysql-password ) myPass="$2"; shift 2;;
            -mt | --mysql-tables ) myTable="$2"; shift 2;;
            -vh | --vertica-host ) vdbHost="$2"; shift 2;;
            -vd | --vertica-database ) vdbDb="$2"; shift 2;;
            -vu | --vertica-user ) vdbUser="$2"; shift 2;;
            -vp | --vertica-password ) vdbPass="$2"; shift 2;;
            -f | --force ) force=1; shift 1;;
            -v | --verbose ) verbose=1; shift 1;;
        esac
    done

if [[ -z $myHost ]]; then echo "$0: --mysql-host should be defined"; exit 1; fi
if [[ -z $myDb ]]; then  echo "$0: --mysql-database should be defined"; exit 1; fi
if [[ -z $myUser ]]; then echo "$0: --mysql-user should be defined"; exit 1; fi
if [[ -z $myPass ]]; then echo "$0: --mysql-password should be defined"; exit 1; fi
if [[ -z $myTable ]]; then echo "$0: --mysql-tables should be defined"; exit 1; fi
if [[ -z $vdbHost ]]; then echo "$0: --vertica-host should be defined"; exit 1; fi
if [[ -z $vdbDb ]]; then echo "$0: --vertica-database should be defined"; exit 1; fi
if [[ -z $vdbUser ]]; then echo "$0: --vertica-user should be defined"; exit 1; fi
if [[ -z $vdbPass ]]; then echo "$0: --vertica-password should be defined"; exit 1; fi

echo "$myHost $myDb $myUser $myPass $myTable $vdbHost $vdbDb $vdbUser $vdbPass $force $verbose "

exit 0;

 #${sshCmd} ${myHost} sudo mkdir -p /root/tmp
 #${sshCmd} ${myHost} sudo rm -f /root/tmp/*
 #${sshCmd} ${myHost} sudo chown -R mysql:mysql /root/tmp
 #echo "mysqldump --lock-tables=false --compatible=postgresql --fields-terminated-by=,  --fields-enclosed-by=\\\" --tab='/root/tmp' ${myDb} ${myTable}"|${sshCmd} ${myHost} sudo bash

#${sshCmd} ${myHost} sudo bash < ./prepare.sh

#${sshCmd} ${vdbHost} sudo chmod -R 777 /home/dbadmin/tmp/
#scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${myHost}:/root/tmp/*.prep ./
#scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no ./*.prep ${vdbHost}:/home/dbadmin/tmp/
#${sshCmd} ${vdbHost} sudo chmod -R 777 /home/dbadmin/tmp/

#if [[ "$1" == "force" ]]; then
#    echo "== DROP TABLE (with force arg)"
#    echo -e "DROP TABLE IF EXISTS openx.${myTable} CASCADE;\n \i /home/dbadmin/tmp/${myTable}.sql.prep"|${sshCmd} ${vdbHost} /opt/vertica/bin/vsql -w${vdbPass} -d ${vdbDb} -U ${vdbUser}
#fi
#xsize=$(echo ls -la /root/tmp/conversions.txt |awk '{ print $5 }'|${sshCmd} ${myHost} sudo bash)
#echo "== Piped COPY to VDB:"
#echo "cat /root/tmp/conversions.txt | pv -pterab -s ${xsize}| pigz -4 -p 6 | PGPASSWORD=${vdbPass} psql -w -d ${vdbDb} -U ${vdbUser} -p 5433 -h vdb1.propellerads.com -c \"BEGIN; DELETE FROM openx.conversions; COPY openx.conversions FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT;\"" | ${sshCmd} ${myHost} sudo bash




