#!/usr/bin/env bash
# 同步数据集到原生 App（生成 ZhiYuanTong/Resources/Data/bundle.json）
# 数据集源文件：ZhiYuanTong/Scripts/data/*.ts
# 用法（项目根目录执行）：bash ZhiYuanTong/Scripts/sync-data.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TMP=".export-data.tmp"
trap 'rm -rf "$TMP"' EXIT

# 同步数据管道产物：一分一段表 / 投档线 / 院校主数据随 App 打包（dist 不存在时沿用仓库内已有副本）
DIST="data-pipeline/dist/app_import"
OFFICIAL="ZhiYuanTong/ZhiYuanTong/Resources/Data/official"
if [ -d "$DIST" ]; then
  mkdir -p "$OFFICIAL"
  cp "$DIST"/*.csv "$OFFICIAL"/
  cp data-pipeline/dist/universities_full.csv "$OFFICIAL/universities.csv"
fi

# 用 esbuild 把 TS 脚本打包成 node 可直接执行的 ESM（本地装了就用本地的，否则临时拉取）
if [ -x "node_modules/.bin/esbuild" ]; then
  ESBUILD="node_modules/.bin/esbuild"
else
  ESBUILD="npx --yes esbuild@0.24.0"
fi

$ESBUILD ZhiYuanTong/Scripts/export-data.ts \
  --bundle --platform=node --format=esm --log-level=warning \
  --outfile="$TMP/export-data.mjs"

node "$TMP/export-data.mjs"
