#!/bin/bash -x
set -e
set -o pipefail

echo "connecting hub ($HUB_RPC) <--> client($1@$LND_HOST:$2 -- $3)"
hubpeerid=`lncli --rpcserver $HUB_RPC connect $1@$LND_HOST:$2 | jq -r '.peer_id'`

echo "hub connected (peer #$hubpeerid), opening channel..."

lncli --rpcserver $HUB_RPC openchannel --peer_id $hubpeerid --local_amt $HUB_FUNDING_AMT --remote_amt 0 --num_confs 1

