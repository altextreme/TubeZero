#!/usr/bin/env bash
# YourTube: builds one self-contained sideload zip (web app + lib + launcher).
# No signing and no device password: upload out/TubeZero-*.zip at http://<tv-ip> yourself.
set -euo pipefail
cd "$(dirname "$0")/.."

node tools/yourtube/check-components.mjs
node tools/rm.js dist
npm run build:web
(cd playlet-lib && npx bsc --create-package --sourceMap=false --lintConfig ../config/bslint.jsonc && npm run postbuild --silent)
# a local or parameter named like a namespace function compiles into a reference to that function
node tools/yourtube/check-shadowed-names.js build/playlet-lib
(cd playlet-app && npx bsc --create-package --sourceMap=false --lintConfig ../config/bslint.jsonc)

mkdir -p out
version=$(node -p "require('./package.json').version")
sha=$(git rev-parse --short HEAD)
dirty=$(git diff --quiet && git diff --cached --quiet || echo "-dirty")
outfile="out/TubeZero-${version}-${sha}${dirty}.zip"
cp dist/playlet-app.zip "$outfile"
echo "Built $(pwd)/$outfile"
