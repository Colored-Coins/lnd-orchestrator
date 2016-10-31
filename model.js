import iferr from 'iferr'

module.exports = redis => ({
  loadWallet: (wid, cb) => redis.hgetall('w:'+wid, iferr(cb, w => (console.log('loaded',wid,w), cb(null, { ...w, wid }))))
})
