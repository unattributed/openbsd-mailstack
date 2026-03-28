#!/bin/ksh
set -eu
( set -o pipefail ) 2>/dev/null && set -o pipefail

RELEASE="7.8"
ARCH="amd64"
MIRROR="https://cdn.openbsd.org/pub/OpenBSD"
DEST_DIR="/home/foo/VMs/iso"
FETCH_ISO=1
FETCH_MINIROOT=0

usage() {
  cat <<'USAGE'
usage: fetch-openbsd-amd64-media.ksh [--release 7.8] [--dest-dir DIR] [--fetch-miniroot]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --release) RELEASE="$2"; shift 2 ;;
    --dest-dir) DEST_DIR="$2"; shift 2 ;;
    --fetch-miniroot) FETCH_MINIROOT=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

TAG="$(printf '%s' "$RELEASE" | tr -d '.')"
BASE_URL="${MIRROR}/${RELEASE}/${ARCH}"
mkdir -p "$DEST_DIR"

if [ "$FETCH_ISO" -eq 1 ]; then
  ISO="install${TAG}.iso"
  echo "Fetching ${ISO} from ${BASE_URL}"
  curl -fL "${BASE_URL}/${ISO}" -o "${DEST_DIR}/${ISO}"
fi

if [ "$FETCH_MINIROOT" -eq 1 ]; then
  IMG="miniroot${TAG}.img"
  echo "Fetching ${IMG} from ${BASE_URL}"
  curl -fL "${BASE_URL}/${IMG}" -o "${DEST_DIR}/${IMG}"
fi

echo "Fetch completed into ${DEST_DIR}"
