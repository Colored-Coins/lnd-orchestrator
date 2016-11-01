#!/bin/bash -x
set -e
set -o pipefail

echo "connecting hub ($HUB_RPC) <--> client($1@$LND_HOST:$2 -- $3)"
hubpeerid=`lncli --rpcserver $HUB_RPC connect $1@$LND_HOST:$2 | jq -r '.peer_id'`

echo "hub connected (peer #$hubpeerid), opening channel..."

lncli --rpcserver $HUB_RPC openchannel --peer_id $hubpeerid --local_amt $HUB_FUNDING_AMT --remote_amt 0 --num_confs 1
echo openchannel req: lncli --rpcserver $HUB_RPC openchannel --peer_id $hubpeerid --local_amt $HUB_FUNDING_AMT --remote_amt 0 --num_confs 1

echo waiting for open tx to finalize and be sent...

sed '/PEER: Creating chan barrier for ChannelPoint /q' <(tail -n 1 -f $LND_PATH/$wid/proc.log)
btcctl --simnet --wallet --rpcserver $BTCW_HOST --rpcuser "$BTCW_USER" --rpcpass "$BTCW_PASS" generate 1
