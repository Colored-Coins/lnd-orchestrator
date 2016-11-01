#!/bin/bash -x
set -e
set -o pipefail

lncli --rpcserver $HUB_RPC sendpayment --dest $1 --amt $HUB_AUTOSEND_AMT --debug_send
