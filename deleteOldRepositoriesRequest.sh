#!/usr/bin/env bash

####################################################################
# Clean up script to remove old request files                      #
# This script delete the *.tar archives and the extracted binaries #
# It does not remove the logs and the analysis results             #
#                                                                  #
#                    ~~ RUNS via crontab ~~                        #
####################################################################

# script vars
VAULT_IN="/prod/oss_prod_share/Incoming"
BASE_STORAGE="${VAULT_IN}/Storage"
COMPLETED_REQUEST_REGEX="DONE_*"

find ${BASE_STORAGE} -maxdepth 1 -name ${COMPLETED_REQUEST_REGEX} | while read request_folder; do

  find $request_folder -name "*.tar" -type f -mtime +10 -exec rm -f {} \;
  rm -f "$request_folder/repository/*"
  echo "Binaries deleted on: $(date)." > $request_folder/logs/cleanup.log

done
