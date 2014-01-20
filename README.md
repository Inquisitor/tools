tools
=====

Admin tools like scripts, utilities etc

my2vdb_tab_copy.sh
------------------
This script designed to copy openx.conversions table from MySQL (mm3) to Vertica (vdb1)

Now it is hard configured to use only this databases and this table, but in future it will be upgraded for use it with any mysql/vertica hosts,databases,tables etc. via command arguments

prepare.sh
----------
Used by my2vdb_tab_copy.sh, don't run directly

