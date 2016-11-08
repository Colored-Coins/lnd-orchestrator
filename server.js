import express from 'express'
import { iferr } from 'iferr'

process.env.NODE_ENV != 'production' && require('longjohn')

const
// Initalize Express, Socket.io & Redis
  app   = express()
, redis = require('redis').createClient(process.env.REDIS_URI)

// Model
, { loadWallet }   = require('./model')(redis)
, { provision, getBalance, pay, settle } = require('./lnd')()

// Setup Express
app.set('port', process.env.PORT || 9001)
app.set('host', process.env.HOST || '127.0.0.1')

app.param('wid', (req, res, next, wid) => loadWallet(wid, iferr(next, w => w ? (req.wallet=w, next()) : next(new Error('404')))))

app.use(require('body-parser').json())
app.use(require('morgan')('dev'))

app.post('/provision',     (req, res, next) => provision(iferr(next, wid => res.send(wid))))
app.get ('/w/:wid',        (req, res, next) => getBalance(req.wallet, iferr(next,
                                                 balance => res.send({ ...req.wallet, balance }))))
app.post('/w/:wid/pay',    (req, res, next) => (pay(req.wallet, req.body.dest, req.body.amount), res.sendStatus(204)))
app.post('/w/:wid/settle', (req, res, next) => (settle(req.wallet, req.body.outpoint), res.sendStatus(204)))

// send the full errors, JSON-formatted, when on development mode
app.settings.env == 'development' && app.use((err, req, res, next) => {
  console.error(err.stack || err)
  res.status(err.statusCode||500).send({ message: ''+err, ...err })
})

// Launch
app.listen(app.get('port'), app.get('host'), _ => console.log(`Listening on ${app.get('host')}:${app.get('port')}`))
