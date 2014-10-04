tools
=====

Admin tools like scripts, utilities etc

mysql2vertica.sh
------------------
_Utility to copy tables from MySQL to HP Vertica using CSV files_

_NOTE THAT YOU SHOULD HAVE RUN THIS SCRIPT ONLY ON VERTICA NODE_


    Usage: mysql2vertica.sh <OPTIONS>

        * - option is required

        -mh, --mysql-host       * MySQL hostname
        -md, --mysql-database   * MySQL database name
        -mu, --mysql-user       * MySQL username
        -mp, --mysql-password   * MySQL password
        -mt, --mysql-tables     * Comma-separated table list. With --query you can set only one table
        -vd, --vertica-database * Vertica database name
        -vu, --vertica-user     * Vertica username
        -vp, --vertica-password * Vertica password
        -p , --progress           Show progress bar on processing pipes
        -q,  --query              MySQL query for dump data (part after where), doesn't work with --force
        -f,  --force              Drop and re-create table in Vertica before COPY data
        -v,  --verbose            Be verbose
        -h,  --help               Show this help

csv2vertica.sh
----------------
_This utility load data from CSV, prepare it and COPY to Vertica database_

_You can copy file from remote host, using ssh pipe_

_NOTE THAT YOU SHOULD HAVE RUN THIS SCRIPT ONLY ON VERTICA NODE_


    Usage: csv2vertica.sh <OPTIONS>
    
        * - option is required

            -d,  --database           Vertica database name 
            -u,  --user               Vertica username 
            -p,  --password           Vertica user's password 
            -t,  --table              Table in database to insert data
            -f,  --file               CSV file path
            -r,  --remote             Get CSV file from remote server (via SSH)
                 --port               SSH Port (if --remote is present), default post is 22
            -P,  --progress           Show progress bar (using PipeViewer)
            -a,  --archive            Archive files after processing
            -v,  --verbose            Be verbose
            -h,  --help               Show this help

cnv_transfer.sh
-----------------
_Utility to incremental instert (from last id) and update feature, made with delete and copy from vertica_

vhealth
----------------
Python daemon to check vertica nodes via http (for haproxy health checher)

logSync
----------------
Prototype python module to on demand or realtime sync logs via http put method from another python application

hostsUpdater
----------------
Not completed/prototype module for deploy/update code from git repository with versionning based on tags
Universal prototype + GitUpdater as parent module (it can be configured in json config file)
