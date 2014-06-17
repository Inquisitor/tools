#!/bin/bash

# csv2vertica.sh        - Utility to copy tables from CSV to HP Vertica
#                         It prepare data before copy to vertica-compatible format
#                         NOTE THAT YOU SHOULD HAVE RUN THIS SCRIPT ONLY ON VERTICA NODE
#
#   ! You should have access to --remote server without password !
#
#   ################## DISCLAIMER ##################
#   YOUR USE OF THIS SOFTWARE IS AT YOUR OWN RISK.
#   NOBODY REPRESENT OR WARRANT THAT THE SOFTWARE
#   PRODUCT WILL MEET YOUR REQUIREMENTS OR THAT ITS
#   OPERATION WILL BE UNINTERRUPTED OR ERROR-FREE.
#   ################################################
#
#   @author:    Andrew Yakovlev aka NOX
#   @version:   1.0.3
#   @license:   GPLv3
#   @copy:      Embria.ru (c) 2014

verbose=0
showHelp=0
progress=0
usePigz=0
archive=0
sshPort=22
sshCmd="/usr/bin/ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no"

function filesCount() {
    local count=0
    if [[ -n "${wRemote}" ]]; then
        count=$($sshCmd -p${sshPort} ${wRemote} ls -1 ${wFile} 2>/dev/null|wc -l)
    else
        count=$(ls -1 ${wFile} 2>/dev/null|wc -l)
    fi
    echo ${count};
}

function getWorkFile() {
    local filename
    if [[ -n "${wRemote}" ]]; then
        filename=$(${sshCmd} -p${sshPort} ${wRemote} ls -1 ${wFile} 2>/dev/null|head -n1)
    else
        filename=$(ls -1 ${wFile} 2>/dev/null|head -n1)
    fi
    echo ${filename}
}

function prepareWorkFile(){
    if [[ -n "${wRemote}" ]]; then
        ${sshCmd} -p${sshPort} ${wRemote} gsed -i -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' ${workFile} && echo "OK" || echo "FAIL"
    else
        sed -i -e 's/"0000-00-00"/NULL/g' -e 's/"0000-00-00 00:00:00"/NULL/g' -e 's/\\N/NULL/g' ${workFile} && echo "OK" || echo "FAIL"
    fi
}

while [[ "$#" -gt "0" ]];
    do
        case "$1" in
            -d | --database ) wDb="$2"; shift 2;;           # Vertica databse to insert data
            -u | --user ) wUser="$2"; shift 2;;             # Vertica user
            -p | --password ) wPass="$2"; shift 2;;         # Vertica user's password
            -r | --remote ) wRemote="$2"; shift 2;;         # Get file from remote server via ssh
            --port ) sshPort="$2"; shift 2;;                # SSH Port
            -t | --table ) wTable="$2"; shift 2;;           # Table which will be copied
            -f | --file ) wFile="$2"; shift 2;;             # CSV file path
            -P | --progress ) progress=1; shift 1;;         # Show progress bar (using PipeViewer)
            -a | --archive ) archive=1; shift 1;;           # Archive files after processing
            -v | --verbose ) verbose=1; shift 1;;           # Show debug messages
            -h | --help ) showHelp=1; shift 1;;
        esac
    done

### If --help argument is present, just show help and exit

if [[ "${showHelp}" -eq "1" ]]; then

echo "Usage: csv2vertica.sh <OPTIONS>"
echo "This utility load data from CSV, prepare it and COPY to Vertica database"
echo "    * - option is required"
echo ""
echo "   -d,  --database           Vertica database name "
echo "   -u,  --user               Vertica username "
echo "   -p,  --password           Vertica user's password "
echo "   -t,  --table              Table in database to insert data"
echo "   -f,  --file               CSV file path"
echo "   -r,  --remote             Get CSV file from remote server (via SSH)"
echo "         --port               SSH Port (if --remote is present), default post is 22 "
echo "   -P,  --progress           Show progress bar (using PipeViewer)"
echo "   -a,  --archive            Archive files after processing"
echo "   -v,  --verbose            Be verbose"
echo "   -h,  --help               Show this help"

exit 0;
fi

### Check requiments

if [[ -z ${wDb} ]]; then echo "$0: --database should be defined"; exit 1; fi
if [[ -z ${wUser} ]]; then echo "$0: --user should be defined"; exit 1; fi
if [[ -z ${wPass} ]]; then echo "$0: --password should be defined"; exit 1; fi
if [[ -z ${wTable} ]]; then echo "$0: --table should be defined"; exit 1; fi
if [[ -z ${wFile} ]]; then echo "$0: --file should be defined"; exit 1; fi

vCmd="/opt/vertica/bin/vsql -w${wPass} -U ${wUser} -d ${wDb} "

### Start work
[[ "${verbose}" -eq 1 ]] &&  echo -ne "Start work at $(date '+%Y-%m-%d %H:%M:%S')\n\n";

## Main working loop
while [[ "$(filesCount)" -gt "0" ]]; do
    curFile=$(getWorkFile)
    workFile="${curFile}.wrk"
    [[ "${verbose}" -eq "1" ]] && echo -ne "== Found file ${wRemote}:${curFile}\n";
    [[ "${verbose}" -eq "1" ]] && echo -ne "   Move file to lock it... ";

    ### Move file to ${curFile}.wrk to avoid two copies work with one file
    if [[ -n "${wRemote}" ]]; then
        $sshCmd -p${sshPort} ${wRemote} mv ${curFile} ${workFile} >/dev/null 2>&1; mvRes=$?
    else
        mv ${curFile} ${workFile} >/dev/null 2>&1; mvRes=$?
    fi
    ( [[ "${verbose}" -eq "1" ]] && [[ "${mvRes}" -eq "0" ]] ) && echo "OK" || echo "FAIL"

    ### Prepare work file to avoid zerodate (it isn't supported by Vertica and must be changed to NULL)
    if [[ "${verbose}" -eq "1" ]]; then
        echo -ne "   Prepare ${workFile}... "
        prepareWorkFile
    else
        prepareWorkFile >/dev/null 2>&1
    fi

    ### Determine file size (for PipeViewer)
    [[ -n "${wRemote}" ]] && fileSize=$(${sshCmd} -p${sshPort} ${wRemote} du -sm ${workFile}|awk '{print $1*1024*1024}') || fileSize=$(du -sm ${workFile}|awk '{print $1*1024*1024}')

    ### Set ${pipeCmd} variable - if --progress is present, we use pipe viewer, else cat command will used
    [[ "${progress}" -eq "1" ]] && pipeCmd="pv -pterabf -s ${fileSize}" || pipeCmd="cat"

    [[ "${verbose}" -eq "1" ]] && echo -ne "   Start COPY file to HP Vertica \n";

    ### Copy data to Vertica
    if [[ -n "${wRemote}" ]]; then
        echo "${pipeCmd} ${workFile}"|${sshCmd} -T -p${sshPort} ${wRemote} | ${vCmd} -c "COPY ${wDb}.${wTable} FROM STDIN DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ; "
    else
        echo "${pipeCmd} ${workFile}"| /bin/bash | ${vCmd} -c "COPY ${wDb}.${wTable} FROM STDIN DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT ; "
    fi
    [[ "${verbose}" -eq "1" ]] && echo -ne "   Done. \n";

    ### If archive is present we place work files to tar.xz archive and remove original file
    if [[ "${archive}" -eq "1" ]]; then
        [[ "${verbose}" -eq "1" ]] && echo -ne "   Archive ${workFile}... ";
        if [[ -n "$wRemote" ]]; then
            ${sshCmd} -p${sshPort} ${wRemote} tar -cJf ${curFile}.tar.xz ${workFile} >/dev/null 2>&1; tarRes=$?
            ${sshCmd} -p${sshPort} ${wRemote} rm -f ${workFile} >/dev/null 2>&1
        else
            tar -cJf ${curFile}.tar.xz ${workFile} >/dev/null 2>&1; tarRes=$?
            rm -f ${workFile} >/dev/null 2>&1
        fi
        ( [[ "${verbose}" -eq "1" ]] && [[ "${tarRes}" -eq "0" ]] ) && echo "OK" || echo "FAIL"
    fi
    echo -ne "\n"
done
## End main working loop

[[ "${verbose}" -eq 1 ]] &&  echo -ne "Finish work at $(date '+%Y-%m-%d %H:%M:%S')\n\n";
