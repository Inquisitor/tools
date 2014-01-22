#!/bin/bash

# mysql2vertica.sh      - Utility to copy tables from MySQL to HP Vertica using CSV files
#                         It prepare data before copy to vertica-compatible format
#                         NOTE THAT YOU SHOULD HAVE RUN THIS SCRIPT ONLY ON VERTICA NODE
#   ################## DISCLAIMER ##################
#   YOUR USE OF THIS SOFTWARE IS AT YOUR OWN RISK.
#   NOBODY REPRESENT OR WARRANT THAT THE SOFTWARE
#   PRODUCT WILL MEET YOUR REQUIREMENTS OR THAT ITS
#   OPERATION WILL BE UNINTERRUPTED OR ERROR-FREE.
#   ################################################
#
#   @author:    Andrew Yakovlev aka NOX
#   @version:   1.2.0
#   @license:   GPLv3
#   @copy:      Embria.ru (c) 2014

force=0
verbose=0
showHelp=0

### Parse command line arguments

function stepTime()
{
    case "$1" in
        start)
            stepStart=$(date +%s)
        ;;
        end)
            stepFinish=$(date +%s)
            stepTime=$(expr ${stepFinish} - ${stepStart})
            stepTotal=$(date -u -d @${stepTime} +%H:%M:%S)
            echo ${stepTotal}
        ;;
    esac
}

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

if [[ -z ${myHost} ]]; then echo "$0: --mysql-host should be defined"; exit 1; fi
if [[ -z ${myDb} ]]; then  echo "$0: --mysql-database should be defined"; exit 1; fi
if [[ -z ${myUser} ]]; then echo "$0: --mysql-user should be defined"; exit 1; fi
if [[ -z ${myPass} ]]; then echo "$0: --mysql-password should be defined"; exit 1; fi
if [[ -z ${myTable} ]]; then echo "$0: --mysql-tables should be defined"; exit 1; fi
if [[ -z ${vdbDb} ]]; then echo "$0: --vertica-database should be defined"; exit 1; fi
if [[ -z ${vdbUser} ]]; then echo "$0: --vertica-user should be defined"; exit 1; fi
if [[ -z ${vdbPass} ]]; then echo "$0: --vertica-password should be defined"; exit 1; fi

### Check if required utilities is installed
if [[ ! -f "$(which pv)" ]]; then echo "$0: PipeViewer (pv) is not installed"; exit 2; fi
if [[ ! -f /opt/vertica/bin/vsql ]]; then echo "$0: Vertica SQL client is not installed"; exit 2; fi
if [[ ! -f "$(which mysql)" ]]; then echo "$0: MySQL client is not installed"; exit 2; fi
if [[ ! -f "$(which mysqldump)" ]]; then echo "$0: MySQL-dump is not installed"; exit 2; fi

vCmd="/opt/vertica/bin/vsql -w${vdbPass} -U ${vdbUser} -d ${vdbDb} "

### Convert table list to array
tList=( `echo ${myTable}|tr ',' ' '` );
[[ "${verbose}" -eq 1 ]] && echo "${#tList[@]} table(s) provided to work..."

### Check conflicted options
if [[ -n "${whereClause}" ]] && [[ "${#tList[@]}" -gt "1" ]]; then
    echo "$0: You cannot use --query option with more than 1 table (${#tList[@]} tables used)"
fi

if [[ -n "${whereClause}" ]] && [[ "${force}" -eq "1" ]]; then
    echo "$0: You cannot use --query option with --force"
fi

# Create temporary folder if not exists
mkdir -p ./tmp >/dev/null 2>&1
rm -rf ./tmp/* >/dev/null 2>&1
chmod 777 ./tmp/* >/dev/null 2>&1

### Start work
[[ "${verbose}" -eq 1 ]] &&  echo -ne "Start work at $(date '+%Y-%m-%d %H:%M:%S')\n\n";

### MySQL part -> dump table structure
[[ "${verbose}" -eq "1" ]] && echo -ne "=== Start DUMP data from MySQL\n";
[[ "${verbose}" -eq "1" ]] && echo -ne "==  Execute mysqldump for tables structure... "
stepTime 'start'
mysqldump -h${myHost} -u${myUser} -p${myPass} --lock-tables=false --no-data ${myDb} ${tList[@]} --tab='./tmp' 2>/dev/null; mDumpRes=$?;
tStructCount=$(ls -1 tmp/*.sql 2>/dev/null|wc -l)
timeof="$(stepTime 'end')"
if [[ "${mDumpRes}" -eq "0" ]]; then
    [[ "${verbose}" -eq "1" ]] && echo "OK: ${tStructCount} structure(s) has been dumped. Elapsed time - ${timeof}"
else
    echo -ne "FAIL: mysqldump exited with code ${mDumpRes}\n\nI'm died :(\n"
    exit 5
fi

### Check if --query is defined
if [[ -n "${whereClause}" ]]; then
### If query is defined make dump using select into outfile
    [[ "${verbose}" -eq "1" ]] && echo -ne "==  [MySQL] Defined query: SELECT * FROM ${tList[@]} WHERE ${whereClause} \n"
    [[ "${verbose}" -eq "1" ]] && echo -ne "==  [MySQL] Execute SELECT INTO OUTFILE... "
    stepTime 'start'
    mysql -nCB -N -h${myHost} -u${myUser} -p${myPass} -e "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT * FROM ${myTable} WHERE ${whereClause};" ${myDb} \
    | awk -F '\t' '{ for (i=0; ++i <= NF;) { if (i==NF) { printf "\"%s\"",$(i) } else { printf "\"%s\",",$(i) } }; printf "\n" }' > tmp/${myTable}.txt; mSelectRes=$?;

    tDumpLines=$(cat tmp/${myTable}.txt 2>/dev/null|wc -l 2>/dev/null)
    tBytes=$(ls -lab tmp/${myTable}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)
    tBytesH=$(ls -lah tmp/${myTable}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)
    
    timeof="$(stepTime 'end')"
     
    if [[ "${mSelectRes}" -eq "0" ]]; then
        [[ "${verbose}" -eq "1" ]] && echo -ne "OK: ${tDumpLines} lines (${tBytesH}) has been dumped. Elapsed time - ${timeof}$\n"
    else
        echo -ne "FAIL: mysql exited with code ${mSelectRes}\n\nI'm died :(\n"
        exit 5
    fi
else
### Query not defined -- just dump all tables in for loop
    for tDump in "${tList[@]}"; do
        [[ "${verbose}" -eq "1" ]] && echo -ne "=   [MySQL] Dump table ${tDump}... "
        stepTime 'start'
        mysql -nCB -N -h${myHost} -u${myUser} -p${myPass} -e "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT * FROM ${tDump};" ${myDb} \
        |awk -F '\t' '{ for (i=0; ++i <= NF;) { if (i==NF) { printf "\"%s\"",$(i) } else { printf "\"%s\",",$(i) } }; printf "\n" }' > tmp/${tDump}.txt; mSelectRes=$?;

        tDumpLines=$(cat tmp/${tDump}.txt 2>/dev/null|wc -l 2>/dev/null)
        tBytes=$(ls -lab tmp/${tDump}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)
        tBytesH=$(ls -lah tmp/${tDump}.txt 2>/dev/null|awk '{print $5}' 2>/dev/null)

        timeof="$(stepTime 'end')"

        if [[ "${mSelectRes}" -eq "0" ]]; then
            [[ "${verbose}" -eq "1" ]] && echo -ne "OK: ${tDumpLines} lines (${tBytesH}) has been dumped. Elapsed time - ${timeof}\n"
        else
            echo -ne "FAIL: mysql exited with code ${mSelectRes}\n\nI'm died :(\n"
            exit 5
        fi
    done
fi
[[ "${verbose}" -eq "1" ]] && echo -ne "=== Start prepare data\n";
[[ "${verbose}" -eq "1" ]] && echo -ne "==  Structures prepare\n";

stepTime 'start'

for strFile in `ls -1 tmp/*.sql`; do
    [[ "${verbose}" -eq "1" ]] && echo -ne "=   [PREPARE] File: ${strFile}\t";
    cat ${strFile} |perl -pe 's/\S*int\(\d+\)/int/g' |sed -e "s/enum('t','f')/boolean/ig" -e 's/UNIQUE KEY/KEY/ig' -e 's/PRIMARY KEY/KEY/ig' -e 's/unsigned//g' -e 's/ text/ varchar(65000)/ig' -e 's/ double / float /ig' | perl -pe 's/CHARACTER SET \w+ //ig' | perl -pe 's/ enum\(\S+\) / varchar(16) /g' | grep -Fv '/*!' | grep -v '^DROP ' | perl -pe 's/ float(\S+)/ float/g' | perl -pe 's/COMMENT .*,\s*$/,/ig' | grep -v '^USE ' | grep -v '^\s*KEY ' | perl -pe 's/,\s*\n\);/);/gs' > ${strFile}.prep
    sed -i 's/"//g' ${strFile}.prep
    sed -i 's/\(CREATE TABLE\) \([a-z_]*\)/\1 '${vdbDb}'\.\2/' ${strFile}.prep
    sed -i 's/^--.*//' ${strFile}.prep
    sed -i "s/NOT NULL DEFAULT '0000-00-00'/DEFAULT NULL/" ${strFile}.prep
    sed -i "s/NOT NULL DEFAULT '0000-00-00 00:00:00'/DEFAULT NULL/" ${strFile}.prep
    sed -i "s/date DEFAULT '0000-00-00'/date DEFAULT NULL/ig" ${strFile}.prep
    sed -i "s/date NOT NULL/date DEFAULT NULL/g" ${strFile}.prep
    sed -i "s/ KEY.*//" ${strFile}.prep
    sed -i '/^$/d' ${strFile}.prep
    sed -i '/^ *$/d' ${strFile}.prep
    sed -i "N;/)\;/s/,\n/\n/;P;D;" ${strFile}.prep
    sed -i "s/unique int  NOT NULL/\"unique\" int  NOT NULL/" ${strFile}.prep
    sed -i -e "s/desc varchar(65000) NOT NULL/\"desc\" varchar(65000) NOT NULL/" -e "s/double(8,4)/DOUBLE PRECISION/g" ${strFile}.prep
    sed -i "s/ enum('new','accepted','in discussion','exist','declined by us','refused by adv','active','disappeared','pending')/ VARCHAR(20)/g" ${strFile}.prep
    sed -i "s/datetime NOT NULL/datetime DEFAULT NULL/g" ${strFile}.prep
    sed -i "s/timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP/timestamp DEFAULT CURRENT_TIMESTAMP/g" ${strFile}.prep
    sed -i "s/ bit(1)/ BINARY/g" ${strFile}.prep
done

timeof="$(stepTime 'end')"
[[ "${verbose}" -eq "1" ]] && echo "OK. Elapsed time - ${timeof}"


[[ "${verbose}" -eq "1" ]] && echo -ne "==  Dumped data prepare\n";
for txtFile in `ls -1 tmp/*.txt`; do
    stepTime 'start'
    [[ "${verbose}" -eq "1" ]] && echo -ne "=   [PREPARE] File: ${txtFile}... ";
    sed -i -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' ${txtFile}
    timeof="$(stepTime 'end')"
    [[ "${verbose}" -eq "1" ]] && echo "OK. Elapsed time - ${timeof}"
done

[[ "${verbose}" -eq "1" ]] && echo -ne "=== Start COPY to HP Vertica\n"
for vTable in "${tList[@]}"; do
    stepTime 'start'
    [[ "${verbose}" -eq "1" ]] && echo -ne "==  Process table ${vTable}...\n"
    if [[ "${force}" -eq "1" ]]; then
        # If force is present, DROP and CREATE table
        $vCmd -c "DROP TABLE ${vdbDb}.${vTable};"
        cat tmp/${vTable}.sql.prep|$vCmd
        cat tmp/${vTable}.txt|pigz -5 -p 8|$vCmd -c "COPY ${vdbDb}.${vTable} FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' REJECTED DATA '/home/dbadmin/rejected_${vTable}.log' EXCEPTIONS '/home/dbadmin/exceptions_${vTable}.log' DIRECT ;"
    else
        if [[ -n "${whereClause}" ]]; then
            cat tmp/${vTable}.txt|pigz -5 -p 8|$vCmd -c "BEGIN; DELETE FROM ${vdbDb}.${vTable} WHERE ${whereClause}; COPY ${vdbDb}.${vTable} FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ;"
         else
            if [[ "${verbose}" -eq "1" ]]; then
                cat tmp/${vTable}.txt|pv -pterab -s `du -sm tmp/${vTable}.txt |awk '{print $1*1024*1024}'`|pigz -5 -p 8|$vCmd -c "BEGIN; DELETE FROM ${vdbDb}.${vTable}; COPY ${vdbDb}.${vTable} FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ;"
            else
                cat tmp/${vTable}.txt|pigz -5 -p 8|$vCmd -c "BEGIN; DELETE FROM ${vdbDb}.${vTable}; COPY ${vdbDb}.${vTable} FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ;"
            fi
         fi
    fi
    timeof="$(stepTime 'end')"
    [[ "${verbose}" -eq "1" ]] && echo "DONE. Elapsed time - ${timeof}"
done
[[ "${verbose}" -eq 1 ]] &&  echo -ne "\n\nFinish work at $(date '+%Y-%m-%d %H:%M:%S')\n\n";


