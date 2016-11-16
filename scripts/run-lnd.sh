#!/bin/bash
set -e
set -o pipefail
#trap 'exit' SIGINT SIGTERM
#trap 'kill -- -$$' EXIT

source ../.env

wid=$1
peerport=$2
rpcport=$3

wdir="$LND_PATH/$wid"
lndlog="$wdir/proc.log"
lndrpc="$LND_HOST:$rpcport"

if [ -d "$wdir" ]; then>&2 echo "duplicate wallet identifier"; exit 1; fi

mkdir -p "$wdir" "$wdir/logs/$LND_NETWORK"

echo "Starting lnd, wid=$wid, peerport=$peerport, rpcport=$rpcport"

source $LND_ENV && lnd --$LND_NETWORK \
    --rpcuser "$BTCD_USER" --rpcpass "$BTCD_PASS" \
    --datadir "$wdir/data" --logdir "$wdir/logs" \
    --listen $peerport --peerport $peerport --rpcport $rpcport \
    --debuglevel trace \
    --debughtlc \
    2>&1 > $lndlog \
    &
lndpid=$!
echo "__INIT__ $lndpid"

#echo "   ... waiting for log file"
#inotifywait -t 3 -e create,open -q "$(dirname $lndlog)"
#echo "   ... lnd running, pid=$lndpid, log=$lndlog"


echo "   ... waiting for RPC server"
sed '/RPCS: RPC server listening on /q' <(tail -n 1 -F "$lndlog")
echo "   ... RPC server $lndrpc ready"
#ps --ppid $$ aux

# Get node info, announce 'ready' event
info=`lncli --rpcserver $lndrpc getinfo | jq -c .`
idpub=`echo "$info" | jq -r '.identity_pubkey'`
#idaddr=`echo "$info" | jq -r '.identity_address'` # not used anymore in upstream lnd

echo "__READY__ $idpub $peerport $rpcport"

# Parse lnd logs into __EVENT__s
tail -n 0 -f "$lndlog" --pid $$ | gawk --bignum -v SATOSHI=100000000 '
  { print; }

  match($0, /PEER: New channel active ChannelPoint\(([a-f0-9]+:[0-9]+)\) with peerId/, m) {
    print "__CH_OPEN__ " m[1]
  }

  match($0, /LNWL: ChannelPoint\(([a-f0-9]+:[0-9]+)\): (local|remote) chain: our_balance=([^ ]+) BTC, their_balance=([^ ]+) BTC, height=([0-9]+)/, m) {
    # outpoint, local|remote, height, ourBalance, theirBalance
    print "__STATE_CHAIN__ " m[1] " " m[2] " " m[5] " " (m[3]*SATOSHI) " " (m[4]*SATOSHI)
    }

    match($0, /LNWL: ChannelPoint\(([a-f0-9]+:[0-9]+)\): state transition accepted: our_balance=([^ ]+) BTC, their_balance=([^ ]+) BTC, height=([0-9]+), ourIndex=([0-9]+), theirIndex=([0-9]+)/, m) {
    # outpoint, height, ourIndex, theirIndex ourBalance, theirBalance
    print "__STATE_ACCEPT__ " m[1] " " m[4] " " m[5] " " m[6] " " (m[2]*SATOSHI) " " (m[3]*SATOSHI)
  }

  match($0, /PEER: Executing cooperative closure of ChanPoint\(([a-f0-9]+:[0-9]+)\) with peerID\([0-9]+\), txid=([0-9a-f]+)/, m) {
    # outpoint, txid, peerid
    print "__CH_SETTLE_INIT__ " m[1] " " m[3] " " m[2]
  }

  match($0, /PEER: ChannelPoint\(([a-f0-9]+:[0-9]+)\) is now closed at height /, m) {
    # outpoint
    print "__CH_SETTLE_DONE__ " m[1]
  }

  match($0, / \[ERR\] (.*)/, m) {
    print "__ERROR__ lnd: " m[1]
  }

  match($0, /HSWC: Unable to send payment, insufficient capacity/, m) {
    print "__WARN__ Insufficient capacity"
  }

  { fflush() }
'

