#!/bin/bash
set -euo pipefail

OUTPUT="${1:?usage: prepare_runtime.sh <publish-output>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/runtime-versions.env"

WORK_DIR="${RUNNER_TEMP:-/tmp}/v2rayn-macos12-runtime"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

export MACOSX_DEPLOYMENT_TARGET=12.0
export GOTOOLCHAIN=local
EXPECTED_GO_PREFIX="go${GO_VERSION%.x}"
ACTUAL_GO_VERSION="$(go env GOVERSION)"
if [[ "$ACTUAL_GO_VERSION" != "$EXPECTED_GO_PREFIX"* ]]; then
  echo "Expected Go ${GO_VERSION} for Monterey, got ${ACTUAL_GO_VERSION}"
  exit 1
fi

echo "==> Rebuilding SQLite ${SQLITE_VERSION} for macOS ${MACOSX_DEPLOYMENT_TARGET}+"
SQLITE_ZIP="$WORK_DIR/sqlite-amalgamation-${SQLITE_AMALGAMATION}.zip"
wget -q -O "$SQLITE_ZIP" \
  "https://www.sqlite.org/${SQLITE_YEAR}/sqlite-amalgamation-${SQLITE_AMALGAMATION}.zip"

# Python's hashlib normally exposes SHA3-256 even when the sha3sum utility is absent.
python3 - "$SQLITE_ZIP" "$SQLITE_SHA3_256" <<'PY'
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
expected = sys.argv[2].lower()
h = hashlib.sha3_256()
with path.open("rb") as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b""):
        h.update(chunk)
actual = h.hexdigest()
if actual != expected:
    raise SystemExit(f"SQLite SHA3-256 mismatch: {actual} != {expected}")
print(f"SQLite SHA3-256 verified: {actual}")
PY

unzip -q "$SQLITE_ZIP" -d "$WORK_DIR/sqlite"
SQLITE_C="$WORK_DIR/sqlite/sqlite-amalgamation-${SQLITE_AMALGAMATION}/sqlite3.c"
clang \
  -arch arm64 \
  -dynamiclib \
  -O2 \
  -fPIC \
  -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET" \
  -install_name "@rpath/libe_sqlite3.dylib" \
  -DSQLITE_THREADSAFE=1 \
  -DSQLITE_ENABLE_COLUMN_METADATA \
  -DSQLITE_ENABLE_DBSTAT_VTAB \
  -DSQLITE_ENABLE_FTS5 \
  -DSQLITE_ENABLE_MATH_FUNCTIONS \
  -DSQLITE_ENABLE_RTREE \
  -DSQLITE_ENABLE_STAT4 \
  -o "$OUTPUT/libe_sqlite3.dylib" \
  "$SQLITE_C"
chmod 755 "$OUTPUT/libe_sqlite3.dylib"

echo "==> Rebuilding Xray ${XRAY_TAG} with Go $(go version)"
git clone -q --depth 1 --branch "$XRAY_TAG" https://github.com/XTLS/Xray-core.git "$WORK_DIR/xray"
pushd "$WORK_DIR/xray" >/dev/null
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 \
  go build \
    -trimpath \
    -buildvcs=false \
    -gcflags="all=-l=4" \
    -ldflags="-X github.com/xtls/xray-core/core.build=${XRAY_TAG#v} -s -w -buildid=" \
    -o "$WORK_DIR/xray-bin" \
    ./main
popd >/dev/null
install -m 755 "$WORK_DIR/xray-bin" "$OUTPUT/bin/xray/xray"

echo "==> Rebuilding sing-box ${SING_BOX_TAG} without the cgo-only Naive outbound"
git clone -q --depth 1 --branch "$SING_BOX_TAG" https://github.com/SagerNet/sing-box.git "$WORK_DIR/sing-box"
pushd "$WORK_DIR/sing-box" >/dev/null
SING_BOX_VERSION="${SING_BOX_TAG#v}"
BUILD_TAGS="$(cat release/DEFAULT_BUILD_TAGS_OTHERS)"
LDFLAGS_SHARED="$(cat release/LDFLAGS)"
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 \
  go build \
    -trimpath \
    -tags "$BUILD_TAGS" \
    -ldflags="-X github.com/sagernet/sing-box/constant.Version=${SING_BOX_VERSION} ${LDFLAGS_SHARED} -s -w -buildid=" \
    -o "$WORK_DIR/sing-box-bin" \
    ./cmd/sing-box
popd >/dev/null
install -m 755 "$WORK_DIR/sing-box-bin" "$OUTPUT/bin/sing_box/sing-box"

echo "==> Runtime replacements"
"$OUTPUT/bin/xray/xray" version | head -n 3
"$OUTPUT/bin/sing_box/sing-box" version | head -n 3
file "$OUTPUT/libe_sqlite3.dylib" "$OUTPUT/bin/xray/xray" "$OUTPUT/bin/sing_box/sing-box"
