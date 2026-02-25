#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <owner/repo>" >&2
  echo "example: $0 yourname/flux-lang" >&2
  exit 1
fi

REPO="$1"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
ASSET_NAME="flux-linux-x86_64.tar.gz"
BIN_DIR="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share/flux"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd grep
need_cmd chmod

echo "Resolving latest release for ${REPO}..."
asset_url="$(
  curl -fsSL "$API_URL" \
  | grep -Eo '"browser_download_url":[[:space:]]*"[^"]+"' \
  | cut -d'"' -f4 \
  | grep "/${ASSET_NAME}$" \
  | head -n1
)"

if [[ -z "${asset_url:-}" ]]; then
  echo "could not find asset ${ASSET_NAME} in latest release" >&2
  echo "expected release asset name: ${ASSET_NAME}" >&2
  exit 1
fi

echo "Downloading ${ASSET_NAME}..."
curl -fL "$asset_url" -o "$TMP_DIR/$ASSET_NAME"

mkdir -p "$TMP_DIR/extract"
tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR/extract"

mkdir -p "$BIN_DIR" "$SHARE_DIR"
cp "$TMP_DIR/extract/bin/flux" "$BIN_DIR/flux"
cp "$TMP_DIR/extract/share/flux/flux0" "$SHARE_DIR/flux0"
chmod +x "$BIN_DIR/flux" "$SHARE_DIR/flux0"
rm -f "$BIN_DIR/flux0"

echo "Installed:"
echo "  $BIN_DIR/flux"
echo "  $SHARE_DIR/flux0"
echo
echo "If 'flux' is not found, add this to your shell profile:"
echo "  export PATH=\"$HOME/.local/bin:\$PATH\""
