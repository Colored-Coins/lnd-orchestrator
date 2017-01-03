import path from 'path'
import iferr from 'iferr'
import brev from 'buffer-reverse'
import { spawn } from 'child_process'
import { fromStream  } from 'rx-node'
import grpc from 'grpc'
import { Lightning, ChannelBalanceRequest, SendRequest, CloseChannelRequest, ChannelPoint, Invoice } from 'lnrpc'

const SCRIPTS = path.join(__dirname, 'scripts')
    , PROVISION_SCRIPT = path.join(SCRIPTS, 'provision-lnd-wid.sh')
    , { LND_HOST } = process.env

module.exports = _ => ({
  provision: cb => {
    cb = ((cb, ran) => (err, wid) => ran
      ? (/tail: write error/.test(''+err) || console.error(new Error('should be called once').stack, '\nargs: ', err, wid))
      : (ran=true, cb(err, wid))
    )(cb, false) // (es6 iife)
    // @TODO the 'tail: write error' errors do not cause any harm (and are so ignored),
    //       but should be fixed eventually

    const proc = spawn(PROVISION_SCRIPT, {cwd: SCRIPTS, detached: true})
    proc.stdout.on('data', b => {
      let d = b.toString(), m

      if (d === '__OVER_CAPACITY__\n') cb(503 /* Service Unavailable */)
      else if (m = d.match(/__WID__ (\S+)/)) (proc.kill('SIGKILL'), cb(null, m[1]))
      else cb(new Error('invalid stdout: ' + d))
    })
    proc.stderr.on('data', d => cb(new Error('provision-lnd stderr: ' + d.toString())))
    proc.on('error', cb)
  }

, getBalance: (wallet, cb) =>
    lndClient(wallet.rpcport).channelBalance(
      new ChannelBalanceRequest
    , iferr(cb, b => cb(null, b.balance))
    )

, pay: (wallet, { dest, amount, rhash }) =>
    lndPayStream(wallet.rpcport)
      .write(new SendRequest(toBuffer(dest), +amount, toBuffer(rhash || '')))

, settle: (wallet, outpoint) =>
    lndClient(wallet.rpcport).closeChannel(
      new CloseChannelRequest(toChannelPoint(outpoint))
    )
, addInvoice: (wallet, { amount, memo, receipt, preimage }, cb) =>
    lndClient(wallet.rpcport)
      .addInvoice(new Invoice({
        value: +amount
      , memo
      , r_preimage: toBuffer(preimage)
      , receipt: toBuffer(receipt || '')
      }), iferr(cb, r => cb(null, r.r_hash)))
})


const toBuffer = x => new Buffer(x, 'hex')
    , toChannelPoint = (point, [ txid, index ] = point.split(':')) => new ChannelPoint({ funding_txid: brev(toBuffer(txid)), output_index: +index })

// @TODO: LRU
const lndClient = (_store => rpcport =>
  _store[rpcport] || (_store[rpcport] = new Lightning(LND_HOST+':'+rpcport, grpc.credentials.createInsecure()))
)({})

const lndPayStream = (_store => rpcport =>
  (_store[rpcport] || (_store[rpcport] = lndClient(rpcport).sendPayment()))
)({})
