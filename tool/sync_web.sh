#!/usr/bin/env bash
# Копирует конструктор с сайта в программу «Показ».
# Запуск из папки программы:  tool/sync_web.sh ../tile-shop-site
# (путь — к папке репозитория сайта; по умолчанию ../tile-shop-site)
set -euo pipefail
SITE="${1:-../tile-shop-site}/public"
DEST="assets/web"
if [ ! -f "$SITE/index.html" ]; then echo "Не найден сайт: $SITE/index.html" >&2; exit 1; fi
rm -rf "$DEST"
mkdir -p "$DEST"
# всё, кроме админки и загруженных фото
for d in nav home catalog constructor new sizes contacts cart shared; do cp -r "$SITE/$d" "$DEST/"; done
cp "$SITE/index.html" "$SITE/favicon.svg" "$DEST/"
echo "Готово: конструктор скопирован в $DEST"
