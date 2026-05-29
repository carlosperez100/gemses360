# GEMSES360

Plataforma SaaS (cascarón multi-tenant) para EsSalud / IPRESS basada en el **Modelo GEMSES**.
Aplicación de un solo archivo (`index.html`, HTML + CSS + JavaScript, sin build) con persistencia en `localStorage`.

## Módulos
- **Gestión de Indicadores** (módulo insignia): ciclo DMAIC del libro GEMSES —
  Definir → Medir → Analizar → Implementar → Controlar, secuencial y dependiente.
  - Recolección por **encuesta** o **ingreso manual**, con periodos fechados (inicio/fin).
  - Plan de mejora **5W+2H** con responsable, fechas, nivel (Proyecto/Procesos/Actividades) y control de actividades.
  - **Controlar**: verificación de impacto con nueva medición (base vs. post).
  - **Línea de tiempo** de hitos, catálogos editables y analítica (regresión, pronóstico, anomalías, estacionalidad).
- **Pasarela de pagos**: autorización automática del módulo por **monto** o por **código de acceso** (por persona, con costo mensual y vigencia).
- **Administración de códigos** (rol admin): genera y gestiona códigos de acceso.

## Acceso de prueba
- **Admin:** `admin` / `123`
- **Demo:** `demo@gemses360.com` / `gemses`

## Uso local
Abre `index.html` en el navegador. No requiere servidor ni instalación.

## Despliegue en servidor propio (Nginx + HTTPS)

Dominio: **gemses360.metacalidad.cloud** → servidor `31.97.86.140`.

1. **DNS** (en tu panel): registro **A** `gemses360` → `31.97.86.140`. Espera la propagación.
2. **Conéctate al servidor** por SSH: `ssh root@31.97.86.140`
3. **Descarga e instala** (repo privado: pedirá usuario `carlosperez100` y un *Personal Access Token* de GitHub como contraseña):
   ```bash
   sudo apt update && sudo apt install -y git
   sudo git clone https://github.com/carlosperez100/gemses360.git /var/www/gemses360
   sudo bash /var/www/gemses360/deploy/setup.sh
   ```
   El script `setup.sh` instala Nginx + Certbot, configura el sitio y emite el certificado HTTPS.
4. Visita **https://gemses360.metacalidad.cloud**

### Actualizar tras nuevos cambios
```bash
sudo bash /var/www/gemses360/deploy/update.sh
```

## Estructura
```
index.html                     # La aplicación completa
README.md
deploy/
  gemses360.nginx.conf         # Configuración del sitio Nginx
  setup.sh                     # Instalación inicial (una vez)
  update.sh                    # Actualizar despliegue (git pull + reload)
```
