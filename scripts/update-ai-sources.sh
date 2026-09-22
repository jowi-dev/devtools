#!/usr/bin/env bash
# Refresh nix/pkgs/ai-sources.json to the latest upstream releases of
# claude-code and opencode. Uses upstream-published checksums, so nothing is
# downloaded beyond a few small JSON documents.
#
# Usage: scripts/update-ai-sources.sh
#   CLAUDE_CODE_CHANNEL=stable scripts/update-ai-sources.sh  # pin the slower channel
#
# After running: review the diff, commit, then `make switch`.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=nix/pkgs/ai-sources.json

GCS=https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
CC_CHANNEL="${CLAUDE_CODE_CHANNEL:-latest}"
CC_VERSION=$(curl -fsS "$GCS/$CC_CHANNEL")
CC_MANIFEST=$(curl -fsS "$GCS/$CC_VERSION/manifest.json")
CC_DARWIN=$(jq -er '.platforms["darwin-arm64"].checksum' <<<"$CC_MANIFEST")
CC_LINUX=$(jq -er '.platforms["linux-x64-musl"].checksum' <<<"$CC_MANIFEST")

OC_VERSION=$(curl -fsS https://registry.npmjs.org/opencode-ai/latest | jq -er .version)
OC_DARWIN=$(curl -fsS "https://registry.npmjs.org/opencode-darwin-arm64/$OC_VERSION" | jq -er .dist.integrity)
OC_LINUX=$(curl -fsS "https://registry.npmjs.org/opencode-linux-x64-musl/$OC_VERSION" | jq -er .dist.integrity)

jq -n \
  --arg ccv "$CC_VERSION" --arg ccd "$CC_DARWIN" --arg ccl "$CC_LINUX" \
  --arg ocv "$OC_VERSION" --arg ocd "$OC_DARWIN" --arg ocl "$OC_LINUX" \
  '{
    "claude-code": {
      version: $ccv,
      platforms: {
        "aarch64-darwin": { artifact: "darwin-arm64", sha256: $ccd },
        "x86_64-linux": { artifact: "linux-x64-musl", sha256: $ccl }
      }
    },
    opencode: {
      version: $ocv,
      platforms: {
        "aarch64-darwin": { npmPackage: "opencode-darwin-arm64", hash: $ocd },
        "x86_64-linux": { npmPackage: "opencode-linux-x64-musl", hash: $ocl }
      }
    }
  }' > "$OUT"

echo "Pinned: claude-code $CC_VERSION ($CC_CHANNEL channel), opencode $OC_VERSION"
echo "Next: git diff $OUT, commit, then make switch."
