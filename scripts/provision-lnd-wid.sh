#!/bin/bash

source ../limits.env

set -e
set -o pipefail

echo "currently running: " $(pgrep -x lnd | wc -l) >> /tmp/limit.log
echo "max: " $LND_PROCESS_LIMIT >> /tmp/limit.log

if [[ $(pgrep -x lnd | wc -l) -gt $LND_PROCESS_LIMIT ]]; then
  echo "__OVER_CAPACITY__"
  exit 1
fi

# Run provision-lnd.sh, wait until the __WID__ line appears, then print the
# wid and exit immediately (while keeping provision-lnd's jobs running in the background)
sed '/^__WID__ / q' <(./provision-lnd.sh 2>&1 | tee -a /tmp/provision.log &) | tail -n 1

#disown
