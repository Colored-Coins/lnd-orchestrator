#!/bin/bash

set -e
set -o pipefail

# Run provision-lnd.sh, wait until the __WID__ line appears, then print the
# wid and exit immediately (while keeping provision-lnd's jobs running in the background)
sed '/^__WID__ / q' <(./provision-lnd.sh | tee -a /tmp/provision.log &) | tail -n 1

#disown
