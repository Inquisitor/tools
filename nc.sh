#!/bin/bash

nc -d mm3.propellerads.com 8867|pv -pterab -s 14288422294 -f|/opt/vertica/bin/vsql -wYGtQaRSdGrVe1g -d openx -U dbadmin -c "BEGIN; DELETE FROM openx.conversions; COPY openx.conversions FROM STDIN GZIP DELIMITER ',' NULL 'NULL' ENCLOSED BY '\"' DIRECT;"
