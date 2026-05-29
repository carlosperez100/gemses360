#!/usr/bin/env bash
# ============================================================
#  GEMSES360 - Instalacion en servidor (Ubuntu/Debian)
#  Ejecutar UNA sola vez en el servidor (31.97.86.140) como root o con sudo.
#  Uso:
#     sudo bash setup.sh
# ============================================================
set -euo pipefail

DOMAIN="gemses360.metacalidad.cloud"
REPO="https://github.com/carlosperez100/gemses360.git"
WEBROOT="/var/www/gemses360"
EMAIL="carlosperez100@gmail.com"   # para el certificado Let's Encrypt

echo "==> 1/5 Instalando dependencias (nginx, git, certbot)..."
apt update
apt install -y nginx git certbot python3-certbot-nginx

echo "==> 2/5 Clonando el repositorio en ${WEBROOT}..."
mkdir -p "${WEBROOT}"
if [ -d "${WEBROOT}/.git" ]; then
  git -C "${WEBROOT}" pull
else
  # Repo privado: pedira usuario (carlosperez100) y un Personal Access Token como contrasena
  git clone "${REPO}" "${WEBROOT}"
fi
chown -R www-data:www-data "${WEBROOT}"

echo "==> 3/5 Configurando Nginx..."
cp "${WEBROOT}/deploy/gemses360.nginx.conf" /etc/nginx/sites-available/gemses360
ln -sf /etc/nginx/sites-available/gemses360 /etc/nginx/sites-enabled/gemses360
nginx -t
systemctl reload nginx

echo "==> 4/5 Emitiendo certificado HTTPS (Let's Encrypt)..."
echo "    (El dominio ${DOMAIN} ya debe apuntar a este servidor en el DNS)"
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect || \
  echo "!! Certbot fallo. Revisa que el DNS ya propago y reintenta: certbot --nginx -d ${DOMAIN}"

echo "==> 5/5 Verificando renovacion automatica..."
certbot renew --dry-run || true

echo ""
echo "============================================================"
echo " Listo. Visita:  https://${DOMAIN}"
echo " Para actualizar en el futuro:  bash ${WEBROOT}/deploy/update.sh"
echo "============================================================"
