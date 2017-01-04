# lnc-orchestrator

HTTP API for the provisioning and management of lnd daemons.

### Use

Configuration options are specified using environment variables or the `.env` file.
See `env.example` for a list of available options.

Start the web server with `npm start`.

#### `POST /provision`

Starts a new lnd daemon and returns the private wallet id (`wid`),
which is later used as a shared secret for managing the wallet.

```bash
$ curl -i -X POST http://localhost:9001/provision

HTTP/1.1 201 Created

jDm979DCQabEtRMIPY0jwLSKT8DI2socnYNj1AsMtk
```

#### `GET /w/:wid`

Returns information about the given wallet.

```bash
$ curl -i http://localhost:9001/w/graiyOU9Sj9XkO0MD9JjNQYL1aiKO0bZFPb5Aequss

HTTP/1.1 200 OK

{
    "wid":"graiyOU9Sj9XkO0MD9JjNQYL1aiKO0bZFPb5Aequss",
    "pid":"6491",
    "idpub":"0219f7ebea261c78f24dedd3855e70a527d6a5f1c862b9423e6fbe6bcf4256d143",
    "rpcport":"22039",
    "peerport":"22038",
    "balance":"5000"
}
```

#### `POST /w/:wid/pay` `{ dest, amount, rhash }`

Make a payment.

```bash
$ curl -i -X POST http://localhost:9001/w/graiyOU9S.../pay \
       -d idpub=0219f7ebea261c78f24dedd3855e70a527d6a5f1c862b9423e6fbe6bcf4256d143 \
       -d amount=1000

HTTP/1.1 204 No Content
```

#### `POST /w/:wid/settle` `{ outpoint }`

Settle a channel.

```bash
$ curl -i -X POST http://localhost:9001/w/graiyOU9S.../settle \
  -d outpoint=430bd26cb7416ecdb4e4d13a2600f6d4f763c2c357b32aafbbd081de7fd3ed06:0

HTTP/1.1 204 No Content
```

#### `POST /w/:wid/invoice` `{ memo, receipt, amount, preimage }`

Creates an invoice and returns the payment `rhash` (to later by used when making a payment).

```bash
$ curl -i -X POST http://localhost:9001/w/aDpGNdYnHAekp8CKlnITr4VHEdOLBXKxb4rp0ORHw/invoice \
  -d memo=pokemon -d amount=100 \
  -d preimage=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b840

HTTP/1.1 201 Created

91fe83a566f587a348f40e9e009d759c67ecf6e8da3cfe4489227d14e7f9a553
```


