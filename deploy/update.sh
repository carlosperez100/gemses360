#!/usr/bin/env bash
# ============================================================
#  GEMSES360 - Actualizar despliegue
#  Ejecutar cada vez que haya cambios nuevos en GitHub.
#  Uso:  bash /var/www/gemses360/deploy/update.sh
# ============================================================
set -euo pipefail
WEBROOT="/var/www/gemses360"

echo "==> Descargando ultimos cambios..."
git -C "${WEBROOT}" pull
chown -R www-data:www-data "${WEBROOT}"

echo "==> Recargando Nginx..."
nginx -t && systemctl reload nginx
echo "Listo. Cambios publicados."
