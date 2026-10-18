#!/usr/bin/env bash
# Разово настраивает GitHub Actions сборку MargyC и запускает её.
# Запускать из корня репо (~/MargyC), gh уже должен быть залогинен (gh auth login).
set -euo pipefail

if ! command -v gh >/dev/null; then
    echo "нет gh: pkg install gh"
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "gh не залогинен: gh auth login"
    exit 1
fi
if [ ! -f keystore/narezany.jks ]; then
    echo "нет keystore/narezany.jks — положи ключ сюда перед запуском"
    exit 1
fi

mkdir -p .github/workflows
cat > .github/workflows/build.yml <<'YAML'
name: Build MargyC

on:
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'patcher.py'
      - 'Claude.xapk'
      - '.github/workflows/build.yml'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Restore tools cache
        uses: actions/cache@v4
        with:
          path: ~/.cache/claude-mods
          key: claude-mods-tools-v1

      - name: Keystore
        env:
          MARGYC_KEYSTORE_B64: ${{ secrets.MARGYC_KEYSTORE_B64 }}
        run: |
          mkdir -p keystore
          echo "$MARGYC_KEYSTORE_B64" | base64 -d > keystore/narezany.jks

      - name: Build
        run: python3 patcher.py Claude.xapk -o MargyC.apk

      - uses: actions/upload-artifact@v4
        with:
          name: MargyC
          path: MargyC.apk
YAML

echo "секрет MARGYC_KEYSTORE_B64..."
base64 -w0 keystore/narezany.jks | gh secret set MARGYC_KEYSTORE_B64

git add .github/workflows/build.yml
git commit -m "ci: сборка MargyC через GitHub Actions" --allow-empty-message -m "" || true
git push

echo "запускаю workflow..."
gh workflow run build.yml
sleep 5
RUN_ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId')
echo "run $RUN_ID — слежу за логом"
gh run watch "$RUN_ID" --exit-status

echo "скачиваю артефакт..."
gh run download "$RUN_ID" -n MargyC -D .
echo "готово: ./MargyC.apk"

