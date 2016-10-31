import path from 'path'
import iferr from 'iferr'
import { spawn } from 'child_process'
import { fromStream  } from 'rx-node'
import grpc from 'grpc'
import { Lightning, ChannelBalanceRequest, SendRequest, CloseChannelRequest, ChannelPoint, GetInfoRequest } from 'lnrpc'

const SCRIPTS = path.join(__dirname, 'scripts')
    , PROVISION_SCRIPT = path.join(SCRIPTS, 'provision-lnd-wid.sh')

module.exports = _ => ({
  provision: cb => {
    cb = ((cb, ran) => (err, wid) => ran
      ? (/tail: write error/.test(''+err) || console.error(new Error('should be called once').stack, '\nargs: ', err, wid))
      : (ran=true, cb(err, wid))
    )(cb, false) // (es6 iife)
    // @TODO the 'tail: write error' errors do not cause any harm (and are so ignored),
    //       but should be fixed eventually

    const proc = spawn(PROVISION_SCRIPT, {cwd: SCRIPTS, detached: true})
    proc.stdout.on('data', d => {
      let m = d.toString().match(/__WID__ (\S+)/)
      m ? (proc.kill('SIGKILL'), cb(null, m[1])) : cb(new Error('invalid stdout, no wid: ' + d))
    })
    proc.stderr.on('data', d => cb(new Error('provision-lnd stderr: ' + d.toString())))
    proc.on('error', cb)
    const dbgev = (o, label) => o.emit=(emit=>function(...a){return (console.log(label, ...a, '---', (''+a[a.length-1])),emit.apply(this, a))})(o.emit)
    dbgev(proc, 'proc')
    dbgev(proc.stdout, 'proc.stdout')
    dbgev(proc.stderr, 'proc.stderr')
  }
, getBalance: (wallet, cb) => lndClient(wallet.rpcport).channelBalance(new ChannelBalanceRequest, iferr(cb, b => cb(null, b.balance)))
, pay: (wallet, dest, amt, cb) => lndPayStream(wallet.rpcport).write(new SendRequest(new Buffer(dest, 'hex'), +amt))
})


// @TODO: LRU
const lndClient = (_store => rpcport =>
  _store[rpcport] || (_store[rpcport] = new Lightning(process.env.LND_HOST+':'+rpcport, grpc.credentials.createInsecure()))
)({})

const lndPayStream = (_store => rpcport =>
  (_store[rpcport] || (_store[rpcport] = lndClient(rpcport).sendPayment()))
)({})
