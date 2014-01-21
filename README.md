mysql2vertica.sh
================
Utility to copy tables from MySQL to HP Vertica using CSV files
---------------------------------------------------------------
NOTE THAT YOU SHOULD HAVE RUN THIS SCRIPT ONLY ON VERTICA NODE
---------------------------------------------------------------

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
        -q,  --query              MySQL query for dump data (part after where), doesn't work with --force
        -f,  --force              Drop and re-create table in Vertica before COPY data
        -v,  --verbose            Be verbose
        -h,  --help               Show this help
