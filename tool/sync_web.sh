#!/usr/bin/env bash
# Копирует конструктор с сайта в программу.
# Запуск из папки программы:  tool/sync_web.sh ../diyor
# (путь — к папке репозитория сайта; по умолчанию ../diyor)
set -euo pipefail
SITE="${1:-../diyor}/public"
DEST="assets/web"
if [ ! -f "$SITE/index.html" ]; then echo "Не найден сайт: $SITE/index.html" >&2; exit 1; fi
mkdir -p "$DEST/css" "$DEST/js" "$DEST/vendor"
cp "$SITE/index.html" "$SITE/favicon.svg" "$DEST/"
cp "$SITE/css/style.css" "$DEST/css/"
for f in config.js catalog.js i18n.js textures.js plan.js scene3d.js app.js; do cp "$SITE/js/$f" "$DEST/js/"; done
cp "$SITE/vendor/three.bundle.js" "$SITE/vendor/three.LICENSE" "$DEST/vendor/"
echo "Готово: конструктор скопирован в $DEST"
