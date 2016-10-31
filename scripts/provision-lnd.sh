#!/bin/bash
set -e
set -o pipefail
#trap 'exit' SIGINT SIGTERM
#trap 'kill -- -$$' EXIT

source ../.env
REDIS="redis-cli -h ${REDIS_HOST:-localhost} -p ${REDIS_PORT:-6379} -a "\""$REDIS_PASS"\"" -n ${REDIS_DB:-0}"

# Create wid (walletid) and listening ports
wid=`dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr '\n' ' ' | sed -r 's/[ +=/]//g'`
numproc=`$REDIS INCR procnum`
peerport=$((LND_PORT_MIN + numproc * 2))
rpcport=$((peerport + 1))

# Provision new lnd daemon, parse output and publish to redis
./run-lnd.sh $wid $peerport $rpcport | gawk -v wid="$wid" -v REDIS="$REDIS" '
  function redis(cmd) { print "REDIS: " cmd; system(REDIS" "cmd" &") }
  function rpub(wid, data, pubonly) { redis("PUBLISH s:" wid " '\''" data "'\''"); if (!pubonly) redis("RPUSH e:" wid " '\''" data "'\''") }

  { print; }

  # Sent out from run-lnd.sh
  $1 == "__INIT__" {
    redis("HMSET w:" wid " pid " $2);
    rpub(wid, "init");
  }
  $1 == "__READY__" {
    idpub=$2
    redis("HMSET w:" wid " idpub " $2 " peerport " $3 " rpcport " $4);
    rpub(wid, "ready");
    rpub(wid, "wallet {\"wid\":\"" wid "\",\"idpub\":\"" $2 "\"}", 1);
    system("./client-init.sh \"" $2 "\" \"" $3 "\" &")
  }
  $1 == "__CH_INIT__" {
    rpub(wid, "ch_init {\"outpoint\":\"" $2 "\",\"peer\":\"" $3 "\",\"capacity\":\"" $4 "\"}");
  }
  $1 == "__CH_OPEN__" {
    rpub(wid, "ch_open {\"outpoint\":\"" $2 "\"}");
    system("./client-fund.sh \"" idpub "\" &")
  }
  $1 == "__CH_SEND__" {
    rpub(wid, "tx {\"outpoint\":\"" $2 "\",\"height\":\"" $3 "\",\"ourIndex\":\"" $4 "\",\"amount\":\"-" $5 "\"}")
  }
  $1 == "__CH_RECV__" {
    rpub(wid, "tx {\"outpoint\":\"" $2 "\",\"height\":\"" $3 "\",\"theirIndex\":\"" $4 "\",\"amount\":\"" $5 "\"}")
  }
  $1 == "__STATE_CHAIN__" {
    print "got __STATE_CHAIN__"
    rpub(wid, "chain {\"outpoint\":\"" $2 "\",\"chain\":\"" $3 "\",\"height\":\"" $4 "\",\"ourBalance\":\"" $5 "\",\"theirBalance\":\"" $6 "\"}", 1)
  }
  $1 == "__STATE_ACCEPT__" {
    rpub(wid, "accept {\"outpoint\":\"" $2 "\",\"height\":\"" $3 "\",\"ourIndex\":\"" $4 "\",\"theirIndex\":\"" $5 "\",\"ourBalance\":\"" $6 "\",\"theirBalance\":\"" $7 "\"}")
  }

  { fflush() }
' 2>&1 | tee -a /tmp/run-lnd-parsed.log &

# Periodically update the balance (should be updated live, but just to make sure we're always synced)
#(
  #sleep 20
  #while true
  #do
   #channelbalance=`lncli --rpcserver $LND_HOST:$rpcport channelbalance | jq .balance`
   #[[ $channelbalance == "null" ]] && channelbalance=0
   #walletbalance=`lncli --rpcserver $LND_HOST:$rpcport walletbalance | jq .balance`
   #[[ $walletbalance == "null" ]] && walletbalance=0
   #walletbalance=$((walletbalance * 100000000))

   #$REDIS HMSET w:$wid channelbalance $channelbalance walletbalance $walletbalance
   #$REDIS PUBLISH s:$wid 'balance {channelbalance":"'$channelbalance'","walletbalance":"'$walletbalance'"}'
   #sleep 10
  #done
#) &

echo "__WID__ $wid"

