#!/bin/bash

# mysql2vertica.sh      - Utility to copy tables from MySQL to HP Vertica using CSV files
#                       It prepare data before copy to vertica-compatible format
#   @author:    Andrew Yakovlev aka NOX
#   @license:   GPLv3
#   @copy:      Embria.ru (c) 2014

force=0
verbose=0
showHelp=0

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
            -q | --query ) whereClause="$2"; shift 2;;
            -f | --force ) force=1; shift 1;;
            -v | --verbose ) verbose=1; shift 1;;
            -h | --help ) showHelp=1; shift 1;;
        esac
    done

### If --help argument is present, just show help and exit

if [[ "${showHelp}" -eq "1" ]]; then

echo "Usage: mysql2vertica.sh <OPTIONS>"
echo "This utility dump data from MySQL, prepare it and COPY to Vertica database"
echo "    * - option is required"
echo ""
echo "    -mh, --mysql-host       * MySQL hostname"
echo "    -md, --mysql-database   * MySQL database name"
echo "    -mu, --mysql-user       * MySQL username"
echo "    -mp, --mysql-password   * MySQL password"
echo "    -mt, --mysql-tables     * Comma-separated table list. With --query you can set only one table"
echo "    -vd, --vertica-database * Vertica database name"
echo "    -vu, --vertica-user     * Vertica username"
echo "    -vp, --vertica-password * Vertica password"
echo "    -q,  --query              MySQL query for dump data (part after where), doesn't work with --force"
echo "    -f,  --force              Drop and re-create table in Vertica before COPY data"
echo "    -v,  --verbose            Be verbose"
echo "    -h,  --help               Show this help"

exit 0;
fi

### Check if required arguments is present, if not - exit

if [[ -z $myHost ]]; then echo "$0: --mysql-host should be defined"; exit 1; fi
if [[ -z $myDb ]]; then  echo "$0: --mysql-database should be defined"; exit 1; fi
if [[ -z $myUser ]]; then echo "$0: --mysql-user should be defined"; exit 1; fi
if [[ -z $myPass ]]; then echo "$0: --mysql-password should be defined"; exit 1; fi
if [[ -z $myTable ]]; then echo "$0: --mysql-tables should be defined"; exit 1; fi
if [[ -z $vdbDb ]]; then echo "$0: --vertica-database should be defined"; exit 1; fi
if [[ -z $vdbUser ]]; then echo "$0: --vertica-user should be defined"; exit 1; fi
if [[ -z $vdbPass ]]; then echo "$0: --vertica-password should be defined"; exit 1; fi

### Check if required utilities is installed
if [[ ! -f "$(which pv)" ]]; then echo "$0: PipeViewer (pv) is not installed"; exit 2; fi
if [[ ! -f /opt/vertica/bin/vsql ]]; then echo "$0: Vertica SQL client is not installed"; exit 2; fi
if [[ ! -f "$(which mysql)" ]]; then echo "$0: MySQL client is not installed"; exit 2; fi
if [[ ! -f "$(which mysqldump)" ]]; then echo "$0: MySQL-dump is not installed"; exit 2; fi

### Convert table list to array
tList=( `echo $myTable|tr ',' ' '` );
[[ "$verbose" -eq 1 ]] && echo "${#tList[@]} table(s) provided to work..."

### Check conflicted options
if [[ -n "$whereClause" ]] && [[ "${#tList[@]}" -gt "1" ]]; then
    echo "$0: You cannot use --query option with more than 1 table (${#tList[@]} tables used)"
fi

if [[ -n "$whereClause" ]] && [[ "$force" -eq "1" ]]; then
    echo "$0: You cannot use --query option with --force"
fi

mkdir -p ./tmp >/dev/null 2>&1
rm -rf ./tmp/* >/dev/null 2>&1
chmod 777 ./tmp/* >/dev/null 2>&1

### Start work
[[ "$verbose" -eq 1 ]] &&  echo -ne "Start work at $(date '+%Y-%m-%d %H:%M:%S')\n\n";

### MySQL part -> dump table structure
[[ "$verbose" -eq "1" ]] && echo -ne "=== Start DUMP data from MySQL\n";
[[ "$verbose" -eq "1" ]] && echo -ne "==  Execute mysqldump for tables structure... "
mysqldump -h${myHost} -u${myUser} -p${myPass} --lock-tables=false --no-data ${myDb} ${tList[@]} --tab='./tmp' 2>/dev/null; mDumpRes=$?;
tStructCount=$(ls -1 tmp/*.sql 2>/dev/null|wc -l)
if [[ "${mDumpRes}" -eq "0" ]]; then
    [[ "$verbose" -eq "1" ]] && echo "OK: ${tStructCount} structures dumped"
else
    echo -ne "FAIL: mysqldump exited with code ${mDumpRes}\n\nI'm died :(\n"
    exit 5
fi

### Check if --query is defined
if [[ -n "${whereClause}" ]]; then
### If query is defined make dump using select into outfile
    [[ "$verbose" -eq "1" ]] && echo -ne "==  Defined query: SELECT * FROM ${tList[@]} WHERE ${whereClause} \n"
    [[ "$verbose" -eq "1" ]] && echo -ne "==  MySQL SELECT INTO OUTFILE... "
    mysql -nCB -N -h${myHost} -u${myUser} -p${myPass} -e "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT * FROM ${myTable} WHERE ${whereClause};" ${myDb}|awk -F '\t' '{ for (i=0; ++i <= NF;) { if (i==NF) { printf "\"%s\"",$(i) } else { printf "\"%s\",",$(i) } }; printf "\n" }' > tmp/${myTable}.txt; mSelectRes=$?;
    tDumpLines=$(cat tmp/${myTable}.txt 2>/dev/null|wc -l 2>/dev/null)
    tBytes=$(ls -lab tmp/${myTable}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)
    tBytesH=$(ls -lah tmp/${myTable}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)
    if [[ "${mSelectRes}" -eq "0" ]]; then
        [[ "$verbose" -eq "1" ]] && echo -ne "OK: ${tDumpLines} lines (${tBytesH}) has been dumped\n"
    else
        echo -ne "FAIL: mysql exited with code ${mSelectRes}\n\nI'm died :(\n"
        exit 5
    fi
else
### Query not defined -- just dump all tables in for loop
    echo "tt"
fi


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




