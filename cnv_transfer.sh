#!/usr/bin/env bash

startWork=$(date +%s)
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

vSQL="/usr/bin/env vsql -wverticapassword -d verticadb -U dbadmin -Atc"
mySQL="mysql -h1.2.3.4 -usuperuser -psuperpasswd verticadb -nCBN -e"

cpy=$(ps aux|grep bash|grep cnv_transfer|grep -v nano|wc -l);
if [[ "${cpy}" -gt "2" ]]; then
	echo "Another copy of this script is running. Exit"
	exit 3;
fi


echo -ne "Start work at $(date +%c)...\n\n"
stepTime 'start'
echo -ne "== STAGE 1 ==\n"
echo -ne "\tGet latest conversion ID from HP Vertica... \t"
lastID=$(${vSQL} "select max(id) from conversions;"); vRes=$?;
if [[ "${vRes}" -ne "0" ]]; then
	echo -ne "FAIL\nvSQL failed with code ${vRes}\nI'm died :\ \n\n"
	exit 7;
fi

#lastID=6258542074;

echo -ne "${lastID}\n"


echo -ne "\tCalculate number of records... \t\t\t"
mID=$( ${mySQL} "select max(id) from conversions;"); mRes=$?
if [[ "${mRes}" -ne "0" ]]; then
        echo -ne "FAIL\nMySQL failed with code ${mRes}\nI'm died :\ \n\n"
	exit 7;
fi

IDcnt=$(expr ${mID} - ${lastID});
echo -ne "${IDcnt} records found\n"

echo -ne "\t-- IMPORT NEW RECORDS TO VERTICA --\n"
${mySQL} "select id,datetime_click,datetime,zone_id,banner_id,geo,platform,ip,concat(\"\\\\00\",cast(conv(hex(conversion),16,10) as unsigned integer)) as conversion,variable,variable2,price,currency from conversions where id > ${lastID};" \
	|awk -F '\t' '{ for (i=0; ++i <= NF;) { if (i==NF) { printf "\"%s\"",$(i) } else { printf "\"%s\",",$(i) } }; printf "\n" }' \
	|sed -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' -e 's/"NULL"/NULL/g' |pv -lpetrf -w 80 -s ${IDcnt} \
	| ${vSQL} "BEGIN; DELETE FROM verticadb.conversions WHERE id > ${lastID}; COPY verticadb.conversions FROM STDIN DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ;"

echo -ne "STAGE 1 COMPLETED! Elapsed time $(stepTime 'end')\n\n"
stepTime 'start'
echo -ne "== STAGE 2 ==\n"
echo -ne "\tCalculate number of records... \t\t\t"
mCNT=$(${mySQL} "select count(*) from conversions where conversion = b'1' and datetime_click >= '`date +%Y-%m-%d --date='8 day ago'`';"); mRes=$?
if [[ "${mRes}" -ne "0" ]]; then
        echo -ne "FAIL\nMySQL failed with code ${mRes}\nI'm died :\ \n\n"
	exit 7;
fi
echo -ne "${mCNT} records found\n"
echo -ne "\t-- LOAD COMPLETED CONVERSIONS TO VERTICA --\n"
${mySQL} "select id,datetime_click,datetime,zone_id,banner_id,geo,platform,ip,concat(\"\\\\00\",cast(conv(hex(conversion),16,10) as unsigned integer)) as conversion,variable,variable2,price,currency from conversions where conversion = b'1' and datetime_click >= '`date +%Y-%m-%d --date='8 day ago'`';" \
	|awk -F '\t' '{ for (i=0; ++i <= NF;) { if (i==NF) { printf "\"%s\"",$(i) } else { printf "\"%s\",",$(i) } }; printf "\n" }' \
	|sed -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' -e 's/"NULL"/NULL/g' |pv -lpetrf -w 80 -s ${mCNT} \
	| ${vSQL} "TRUNCATE TABLE verticadb.cnv_update; COPY verticadb.cnv_update FROM STDIN DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ; "

echo -ne "\tMake a magick with conversions... "

cnvUpdated=$(${vSQL} "BEGIN; CONNECT TO VERTICA verticadb USER dbadmin PASSWORD 'YGtQaRSdGrVe1g' ON 'localhost',5433; delete from verticadb.conversions where id IN (select id from cnv_update); COPY conversions FROM VERTICA verticadb.cnv_update DIRECT NO COMMIT; COMMIT;"; vRes=$?;)

if [[ "${vRes}" -ne "0" ]]; then
        echo -ne "FAIL\nvSQL failed with code ${vRes}\nI'm died :\ \n\n"
        exit 7;
fi

echo -ne "${cnvUpdated} conversions has been updated\n"

echo -ne "STAGE 2 COMPLETED! Elapsed time $(stepTime 'end')\n\n"
finishWork=$(date +%s); totalWork=$(expr ${finishWork} - ${startWork})
echo -ne "Finish work at $(date +%c)... Total elapsed time $(date -u -d @${totalWork} +%H:%M:%S)\n\n"
