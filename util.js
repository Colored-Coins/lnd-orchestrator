import { Observable as O } from 'rx'
import { randomBytes } from 'crypto'

const debug = require('debug')('LnCC')

export const makeSocketDriver = socket => out$ => (
  out$.subscribe(a => socket.emit(...a)),
  { events: O.fromEvent.bind(O, socket) })

export const formatNumber  = n => n

export const makeWid = _ => randomBytes(32).toString('base64').replace(/\W+/g, '')

export const dbgStreams = streams =>  Object.keys(streams).forEach(k => dbgStream(k, streams[k]))

const dbgStream = (label, o$) => o$.subscribe(
  x => debug(`${label} ->`, x),
  err => debug(`${label} \x1b[91mError:\x1b[0m`, err.stack || err),
  () => debug(`${label} completed`)
)

// expose debug object, call `mdebug.enable()` to enable it
if (typeof window != 'undefined') window.mdebug = debug
