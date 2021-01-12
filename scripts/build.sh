#!/bin/bash
set -xeo pipefail

# `x86_64-osx` is also available, requires osxcross to be installed (see bwt/builder-osx.Dockerfile)
TARGETS=${TARGETS:-x86_64-linux,x86_64-win,arm32v7-linux,arm64v8-linux}

# for stderr logging and automatic detection of bitcoind's data dir location
FEATURES=${FEATURES:-pretty_env_logger,dirs}

[ -f bwt/Cargo.toml ] || (echo >&2 "Missing bwt submodule, run 'git submodule update --init'" && exit 1)

version=$(grep -E '^version =' Cargo.toml | cut -d'"' -f2)

if [[ -n "$SCCACHE_DIR" && -d "$SCCACHE_DIR" ]]; then
  export RUSTC_WRAPPER=$(which sccache)
fi

# Build library for a single platform/variant with the specified feature set
build_platform_variant() {
  local platform_nick=$1
  local platform_rust=$2
  local features=$3
  local variant=$4
  local name=libbwt-$version$variant-$platform_nick
  local filename=$(lib_filename $platform_rust)

  cargo build --release --target $platform_rust --no-default-features --features $FEATURES,$features

  mkdir -p dist/$name
  mv target/$platform_rust/release/$filename dist/$name/
  strip_symbols $platform_rust dist/$name/$filename || true
  cp LICENSE README.md libbwt.h dist/$name/
  pack $name
}

# Build variants (full/electrum_only) for the specified platform
build_platform() {
  if [[ $TARGETS != *"$1"* ]]; then return; fi

  [ -n "$ELECTRUM_ONLY_ONLY" ] || build_platform_variant $1 $2 http,electrum ''
  build_platform_variant $1 $2 electrum '-electrum_only'
}

lib_filename() {
  # Windows dll files ar built as `bwt.dll`, without the `lib` prefix
  local pre=$([[ $1 == *"-windows-"* ]] || echo lib)
  local ext=$([[ $1 == *"-windows-"* ]] && echo .dll || ([[ $1 == *"-apple-"* ]] && echo .dylib || echo .so))
  echo -n ${pre}bwt${ext}
}

strip_symbols() {
  case $1 in
    "x86_64-unknown-linux-gnu") x86_64-linux-gnu-strip $2 ;;
    "x86_64-pc-windows-gnu") x86_64-w64-mingw32-strip $2 ;;
    "x86_64-apple-darwin") x86_64-apple-darwin15-strip $2 ;;
    "armv7-unknown-linux-gnueabihf") arm-linux-gnueabihf-strip $2 ;;
    "aarch64-unknown-linux-gnu") aarch64-linux-gnu-strip $2 ;;
    *) echo >&2 Platform not found: $1; strip $2 ;;
  esac
}

# pack tar.gz with static/removed metadata attrs and deterministic file order for reproducibility
pack() {
  local name=$1
  touch -t 1711081658 dist/$name dist/$name/*
  pushd dist
  TZ=UTC tar --mtime='2017-11-08 16:58:00' --owner=0 --sort=name -I 'gzip --no-name' -chf $name.tar.gz $name
  popd
}

build_platform x86_64-linux   x86_64-unknown-linux-gnu
build_platform x86_64-osx     x86_64-apple-darwin
build_platform x86_64-windows x86_64-pc-windows-gnu
build_platform arm32v7-linux  armv7-unknown-linux-gnueabihf
build_platform arm64v8-linux  aarch64-unknown-linux-gnu
