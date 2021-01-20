# Bitcoin Wallet Tracker - C FFI

[![Build Status](https://travis-ci.org/bwt-dev/libbwt.svg?branch=master)](https://travis-ci.org/bwt-dev/libbwt)
[![Latest release](https://img.shields.io/github/v/release/bwt-dev/libbwt?color=orange)](https://github.com/bwt-dev/libbwt/releases/tag/v0.2.1)
[![Downloads](https://img.shields.io/github/downloads/bwt-dev/libbwt/total.svg?color=blueviolet)](https://github.com/bwt-dev/libbwt/releases)
[![MIT license](https://img.shields.io/github/license/bwt-dev/libbwt.svg?color=yellow)](https://github.com/bwt-dev/libbwt/blob/master/LICENSE)
[![Pull Requests Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/bwt-dev/bwt#developing)

C FFI for [Bitcoin Wallet Tracker](https://github.com/bwt-dev/bwt), a lightweight personal indexer for bitcoin wallets.

`libbwt` allows to programmatically manage bwt's Electrum RPC and HTTP API servers.
It can be used as a compatibility layer for easily upgrading Electrum-backed wallets to support a
Bitcoin Core full node backend (by running the Electrum server *in* the wallet),
or for shipping software that integrates bwt's [HTTP API](https://github.com/bwt-dev/bwt#http-api)
as an all-in-one package.

Support development: [⛓️ on-chain or ⚡ lightning via BTCPay](https://btcpay.shesek.info/)

- [C interface](#c-interface)
- [Installation](#installation)
  - [Electrum only](#electrum-only-variant)
  - [Verifying the signature](#verifying-the-signature)
- [Config options](#config-options)
- [Building from source](#building-from-source)
- [Reproducible builds](#reproducible-builds)
- [License](#license)

> Also see: [bwt](https://github.com/bwt-dev/bwt), [libbwt-jni](https://github.com/bwt-dev/libbwt-jni) and [libbwt-nodejs](https://github.com/bwt-dev/libbwt-nodejs).


## C interface

The interface exposes two functions, for starting and stopping the bwt daemon.
Everything else is done through the Electrum/HTTP APIs.

```c
typedef void (*bwt_init_cb)(void* shutdown_ptr);

typedef void (*bwt_notify_cb)(const char* msg_type, float progress,
                                uint32_t detail_n, const char* detail_s);

int32_t bwt_start(const char* json_config,
                  bwt_init_cb init_cb,
                  bwt_notify_cb notify_cb);

int32_t bwt_shutdown(void* shutdown_ptr);
```

Both functions return `0` on success or `-1` on failure.

#### `bwt_start(json_config, init_cb, notify_cb)`

Start the configured server(s).

This will initialize the daemon and start the sync loop, blocking the current thread.

`json_config` should be provided as a JSON-encoded string. The list of options is available [below](#config-options).
Example minimal configuration:

```
{
  "bitcoind_dir": "/home/satoshi/.bitcoin",
  "descriptors": [ "wpkh(xpub66../0/*)" ],
  "electrum_addr": "127.0.0.1:0"
}
```

> You can configure `electrum_addr`/`http_addr` to `127.0.0.1:0` to bind on any available port.
> The assigned port will be reported back via the `ready:X` notifications (see below).

The function accepts two callbacks: `init_cb` and `notify_cb`.

`init_cb(shutdown_ptr)` will be called with the shutdown pointer (see `bwt_shutdown()`)
right before bwt is started up, after the configuration is validated.

The `notify_cb(msg_type, progress, detail_n, detail_s)` callback will be called with error messages,
information about the running services and progress updates, with the `progress` argument indicating the
current progress as a float from 0 to 1.
The meaning of the `detail_{n,s}` field varies for the different `msg_type`s, which are:

- `progress:sync` - Progress updates for bitcoind's initial block download. `detail_n` contains the unix
  timestamp of the current chain tip.
- `progress:scan` - Progress updates for historical transactions rescanning. `detail_n` contains the estimated
  remaining time in seconds.
- `ready:electrum` - The Electrum server is ready. `detail_s` contains the address the server is bound on,
  as an `<ip>:<port>` string (useful for ephemeral binding on port 0).
- `ready:http` - The HTTP server is ready. `detail_s` contains the address the server is bound on.
- `ready` - Everything is ready.
- `error` - An error occurred during the initial start-up. `detail_s` contains the error message.

> The `detail_s` argument will be deallocated after calling the callback. If you need to keep it around, make a copy of it.
>
> Note that `progress:X` notifications will be sent from a different thread.

This function does not return until the daemon is stopped.

#### `bwt_shutdown(shutdown_ptr)`

Shutdown the bwt daemon.

Should be called with the shutdown pointer passed to `init_cb()`.

If this is called while bitcoind is importing/rescanning addresses,
the daemon will not stop immediately but will be marked for later termination.

## Installation

Pre-built [signed](#verifying-the-signature) & [deterministic](#reproducible-builds) `libbwt` library
files are available for download from the [releases page](https://github.com/bwt-dev/libbwt/releases)
for Linux, Mac, Windows and ARMv7/8.

> ⚠️ The pre-built libraries are meant to make it easier to get started. If you're integrating bwt
> into real-world software, [building from source](#building-from-source) is *highly* recommended.


#### Electrum-only variant

The pre-built libraries are also available for download as an `electrum_only` variant,
which doesn't include the HTTP API server. It is roughly 33% smaller and comes with less dependencies.

#### Verifying the signature

The releases are signed by Nadav Ivgi (@shesek).
The public key can be verified on
the [PGP WoT](http://keys.gnupg.net/pks/lookup?op=vindex&fingerprint=on&search=0x81F6104CD0F150FC),
[github](https://api.github.com/users/shesek/gpg_keys),
[twitter](https://twitter.com/shesek),
[keybase](https://keybase.io/nadav),
[hacker news](https://news.ycombinator.com/user?id=nadaviv)
and [this video presentation](https://youtu.be/SXJaN2T3M10?t=4) (bottom of slide).

```bash
# Download (change x86_64-linux to your platform)
$ wget https://github.com/bwt-dev/libbwt/releases/download/v0.2.1/libbwt-0.2.1-x86_64-linux.tar.gz

# Fetch public key
$ gpg --keyserver keyserver.ubuntu.com --recv-keys FCF19B67866562F08A43AAD681F6104CD0F150FC

# Verify signature
$ wget -qO - https://github.com/bwt-dev/libbwt/releases/download/v0.2.1/SHA256SUMS.asc \
  | gpg --decrypt - | grep x86_64-linux.tar.gz | sha256sum -c -
```

The signature verification should show `Good signature from "Nadav Ivgi <nadav@shesek.info>" ... Primary key fingerprint: FCF1 9B67 ...` and `libbwt-0.2.1-x86_64-linux.tar.gz: OK`.


## Config Options

All options are optional, except for `descriptors`/`xpubs`/`addresses` (of which there must be at least one).

To start the API servers, set `electrum_addr`/`http_addr`.

#### Network and Bitcoin Core RPC
- `network` - one of `bitcoin`, `testnet`, `signet` or `regtest` (defaults to `bitcoin`)
- `bitcoind_url` - bitcoind url (defaults to `http://localhost:<network-rpc-port>/`)
- `bitcoind_auth` - authentication in `<user>:<pass>` format (defaults to reading from the cookie file)
- `bitcoind_dir` - bitcoind data directory (defaults to `~/.bitcoin` on Linux, `~/Library/Application Support/Bitcoin` on Mac, or `%APPDATA%\Bitcoin` on Windows)
- `bitcoind_cookie` - path to cookie file (defaults to `.cookie` in the datadir)
- `bitcoind_wallet` - bitcoind wallet to use (for use with multi-wallet)
- `create_wallet_if_missing` - create the bitcoind wallet if it's missing (defaults to false)

> If bitcoind is running locally on the default port, at the default datadir location and with cookie auth enabled (the default),
> connecting to it should Just Work™, no configuration needed.

#### Address tracking
- `descriptors` - an array of descriptors to track
- `xpubs` - an array of xpubs to track (SLIP32 ypubs/zpubs are supported too)
- `addresses` - an array of addresses to track
- `addresses_file` - path to file with addresses (one per line)
- `rescan_since` - the unix timestamp to begin rescanning from, or 'now' to track new transactions only (the default)
- `gap_limit` - the [gap limit](https://github.com/bwt-dev/bwt#gap-limit) for address import (defaults to 20)
- `initial_import_size` - the chunk size to use during the initial import (defaults to 350)
- `force_rescan` - force rescanning for historical transactions, even if the addresses were already previously imported (defaults to false)

#### General settings
- `poll_interval` - interval for polling new blocks/transactions from bitcoind in seconds (defaults to 5)
- `tx_broadcast_cmd` - [custom command](https://github.com/bwt-dev/bwt#scriptable-transaction-broadcast) for broadcasting transactions
- `verbose` - verbosity level for stderr log messages (0-4, defaults to 0)
- `require_addresses` - when disabled, the daemon will start even without any configured wallet addresses (defaults to true)
- `setup_logger` - enable stderr logging (defaults to true)

#### Electrum
- `electrum_addr` - bind address for electrum server (off by default)
- `electrum_skip_merkle` - skip generating merkle proofs (off by default)

#### HTTP
- `http_addr` - bind address for http server (off by default)
- `http_cors` - allowed cross-origins for http server (none by default)

#### Web Hooks
- `webhooks_urls` - array of urls to notify with index updates

#### UNIX only
- `unix_listener_path` - path to bind the [sync notification](https://github.com/bwt-dev/bwt#real-time-indexing) unix socket (off by default)



## Building from source

Manually build the C FFI library for a single platform (requires Rust):

```bash
$ git clone https://github.com/bwt-dev/libbwt && cd libbwt
$ git checkout <tag>
$ git verify-commit HEAD
$ git submodule update --init

$ cargo build --release --target <platform>
```

The library file will be available in `target/<platform>/release`, named
`libbwt.so` for Linux/Android/ARM, `libbwt.dylib` for OSX, or `bwt.dll` for Windows.

To build the `electrum_only` variant, set `--no-default-features --features electrum`.

## Reproducible builds

The library files for all supported platforms can be reproduced
in a Docker container environment as follows:

```bash
$ git clone https://github.com/bwt-dev/libbwt && cd libbwt
$ git checkout <tag>
$ git verify-commit HEAD
$ git submodule update --init

# Linux, Windows, ARMv7 and ARMv8
$ docker build -t bwt-builder - < bwt/scripts/builder.Dockerfile
$ docker run -it --rm -u `id -u` -v `pwd`:/usr/src/libbwt -w /usr/src/libbwt \
  --entrypoint scripts/build.sh bwt-builder

# Mac OSX (cross-compiled via osxcross)
$ docker build -t bwt-builder-osx - < bwt/scripts/builder-osx.Dockerfile
$ docker run -it --rm -u `id -u` -v `pwd`:/usr/src/libbwt -w /usr/src/libbwt \
  --entrypoint scripts/build.sh bwt-builder-osx

$ sha256sum dist/*.tar.gz
```

You may set `-e TARGETS=...` to a comma separated list of the platforms to build. 
The available platforms are: `x86_64-linux`, `x86_64-osx`, `x86_64-windows`, `arm32v7-linux` and `arm64v8-linux`.

Both variants will be built by default. To build the `electrum_only` variant only, set `-e ELECTRUM_ONLY_ONLY=1`.

The builds are [reproduced on Travis CI](https://travis-ci.org/github/bwt-dev/libbwt/branches) using the code from GitHub.
The SHA256 checksums are available under the "Reproducible builds" stage.

## License

MIT
