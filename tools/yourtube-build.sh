#!/usr/bin/env bash
# YourTube: builds one self-contained sideload zip (web app + lib + launcher).
# No signing and no device password: upload out/YourTube-*.zip at http://<tv-ip> yourself.
set -euo pipefail
cd "$(dirname "$0")/.."

node tools/yourtube/check-components.mjs
node tools/rm.js dist
npm run build:web
(cd playlet-lib && npx bsc --create-package --sourceMap=false --lintConfig ../config/bslint.jsonc && npm run postbuild --silent)
(cd playlet-app && npx bsc --create-package --sourceMap=false --lintConfig ../config/bslint.jsonc)

mkdir -p out
version=$(node -p "require('./package.json').version")
sha=$(git rev-parse --short HEAD)
dirty=$(git diff --quiet && git diff --cached --quiet || echo "-dirty")
outfile="out/YourTube-${version}-${sha}${dirty}.zip"
cp dist/playlet-app.zip "$outfile"
echo "Built $(pwd)/$outfile"
