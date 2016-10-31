#!/bin/bash -x

lncli --rpcserver $HUB_RPC sendpayment --dest $1 --amt $HUB_AUTOSEND_AMT --debug_send
