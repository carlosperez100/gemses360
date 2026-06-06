# 🚀 GEMSES360 — Automatización Completa

Aquí está todo lo que necesitas para **automatizar GEMSES360** con:
- ✅ **Auto-deploy** (cada `git push` → Coolify)
- ✅ **Base de datos centralizada** (Supabase PostgreSQL)
- ✅ **Migración de datos** (localStorage → BD)
- ✅ **Row-Level Security** (cada usuario ve solo sus datos)
- ✅ **Códigos únicos globales** (PG-IPRESS-AÑO-Nº sin colisiones)

---

## 📋 CHECKLIST: Qué ya está hecho

- ✅ `.github/workflows/deploy.yml` — GitHub Actions configurado
- ✅ `migrate-to-supabase.js` — Script de migración listo
- ✅ `supabase-schema.sql` — Schema SQL completo
- ✅ Repo Git: `https://github.com/carlosperez100/gemses360`

---

## ⚙️ PASO 1: Configurar GitHub Actions (5 min)

### 1.1 Obtener tokens de Coolify

Ve a **Coolify** (`https://coolify.io`):

1. Login con tu cuenta
2. Ve a **"GEMSES360"** → **Projects** → **gemses360**
3. Copia el **Webhook URL** (algo como `https://coolify.io/api/deployments?token=...`)
4. Copia tu **Coolify API Token** (desde Settings)

### 1.2 Agregar secrets a GitHub

Ve a **GitHub** (`https://github.com/carlosperez100/gemses360`):

1. Settings → Secrets and variables → Actions
2. Click **"New repository secret"**
3. Agrega:
   - Nombre: `COOLIFY_WEBHOOK` → Valor: el webhook URL de Coolify
   - Nombre: `COOLIFY_TOKEN` → Valor: tu Coolify API Token

### 1.3 Listo

```bash
# Cada vez que hagas:
git commit -am "fix: actualizar GEMSES360"
git push origin main

# → GitHub Actions automáticamente:
# 1. Valida el código
# 2. Dispara Coolify
# 3. Coolify re-deploya a gemses360.metacalidad.cloud
```

---

## ☁️ PASO 2: Crear Supabase (10 min)

### 2.1 Crear proyecto

Ve a **Supabase** (`https://supabase.com`):

1. Click **"New Project"**
2. Nombre: `gemses360-backend`
3. Contraseña: **elige una fuerte** (ej: `Abc123!@#XyZ`)
4. Región: `us-east-1` (o la más cerca de tu hospital)
5. Click **"Create new project"**

Espera 3-5 minutos mientras se inicializa.

### 2.2 Ejecutar schema SQL

Cuando esté listo el proyecto:

1. Ve a **SQL Editor** (en el menu de Supabase)
2. Click **"New Query"**
3. **Copia TODO el contenido de** `supabase-schema.sql`
4. Pégalo en el editor SQL
5. Click **"Run"**

```sql
-- Verás algo como:
-- ✅ CREATE TABLE usuarios
-- ✅ CREATE TABLE planes
-- ✅ CREATE TABLE indicadores
-- ... etc
```

Listo. La BD está inicializada.

### 2.3 Obtener credenciales

Ve a **Project Settings** → **API**:

- **SUPABASE_URL**: Algo como `https://abc123.supabase.co`
- **SUPABASE_ANON_KEY**: Un token largo

Guarda estos valores en `.env` (ver abajo).

---

## 🔐 PASO 3: Configurar variables de entorno

Crea un archivo **`.env`** en la raíz de GEMSES360:

```bash
# .env (NO commitar a Git)
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
DATABASE_URL=postgresql://postgres:tu-contraseña@db.abc123.supabase.co:5432/postgres
COOLIFY_WEBHOOK=https://coolify.io/api/deployments?token=...
COOLIFY_TOKEN=tu-token-coolify
```

**⚠️ IMPORTANTE:**
- NO commitar `.env` a Git (ya está en `.gitignore`)
- Mantener seguro estos tokens

---

## 📊 PASO 4: Migración de datos (10 min)

### 4.1 Exportar localStorage actual

En **GEMSES360** (navegador):

1. Abre la app en `https://gemses360.metacalidad.cloud`
2. Abre DevTools (**F12**)
3. Ve a **Console** y ejecuta:

```javascript
// Exportar localStorage
const export_data = {
  g360_users: localStorage.getItem('g360_users'),
  g360_data: localStorage.getItem('g360_data'),
  g360_maestras: localStorage.getItem('g360_maestras')
};

// Copiar a archivo
const json = JSON.stringify(export_data);
console.log(json);

// Guardar como: localStorage-export.json
```

4. Descarga el JSON y guárdalo como `localStorage-export.json` en la carpeta de GEMSES360

### 4.2 Ejecutar migración

```bash
cd ~/GEMSES360
npm install uuid   # Si no lo tienes

node migrate-to-supabase.js
```

**Output esperado:**

```
🚀 GEMSES360: Migración localStorage → Supabase

📂 Cargando datos de localStorage...
✅ Cargados: 5 usuarios, 12 datos

👥 Migrando usuarios...
  ✅ director@hospital.org
  ✅ supervisor@hospital.org
  ✅ staff@hospital.org

📋 Migrando planes de gestión...
  ✅ PG-HIESC-2024-001
  ✅ PG-HIESC-2024-002
  ✅ PG-HIML-2024-001

📊 Migrando indicadores...
Total: 28 indicadores migrados

🔍 Validando migración...
✅ Usuarios: 5
✅ Planes: 3
✅ Indicadores: 28
✅ Códigos PG-* son únicos globalmente

✅ MIGRACIÓN COMPLETADA
```

---

## 🔌 PASO 5: Refactorizar GEMSES360 (para usar API)

Esto es **la parte más importante**. Necesitas cambiar GEMSES360 para usar las APIs de Supabase en lugar de localStorage.

### 5.1 Crear API client

Crea **`api-client.js`** en GEMSES360:

```javascript
// api-client.js
const SUPABASE_URL = 'https://tu-proyecto.supabase.co';
const SUPABASE_KEY = 'tu-anon-key';

class GemsesAPI {
  constructor() {
    this.token = localStorage.getItem('auth_token'); // Del login
  }

  async request(method, endpoint, body = null) {
    const url = `${SUPABASE_URL}/rest/v1${endpoint}`;
    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    };

    const response = await fetch(url, body ? {...options, body: JSON.stringify(body)} : options);
    return response.json();
  }

  // Planes
  async getPlanes() {
    return this.request('GET', '/planes');
  }

  async crearPlan(datos) {
    return this.request('POST', '/planes', datos);
  }

  async actualizarPlan(id, datos) {
    return this.request('PATCH', `/planes?id=eq.${id}`, datos);
  }

  // Indicadores
  async getIndicadores(plan_codigo) {
    return this.request('GET', `/indicadores?plan_codigo=eq.${plan_codigo}`);
  }

  async crearIndicador(datos) {
    return this.request('POST', '/indicadores', datos);
  }

  // ... etc
}

const api = new GemsesAPI();
```

### 5.2 Cambiar `savePlan()` para usar API

**Antes (localStorage):**
```javascript
function savePlan() {
  localStorage.setItem('g360_data', JSON.stringify(DB));
}
```

**Después (API):**
```javascript
async function savePlan() {
  const response = await api.actualizarPlan(pgData().id, {
    info: pgData().info,
    autodiag: pgData().autodiag,
    pestel: pgData().pestel,
    foda: pgData().foda,
    crono: pgData().crono,
    monitoreo: pgData().monitoreo,
    paso_actual: pgData().paso_actual
  });

  if (response.error) {
    console.error('Error guardando plan:', response.error);
  } else {
    console.log('✅ Plan guardado en Supabase');
  }
}
```

### 5.3 Cambiar `loadPlanes()` para usar API

**Antes:**
```javascript
function loadPlanes() {
  const data = JSON.parse(localStorage.getItem('g360_data') || '{}');
  return data[currentUser.email]?.planes || [];
}
```

**Después:**
```javascript
async function loadPlanes() {
  const planes = await api.getPlanes();
  return planes.filter(p => p.usuario_id === currentUser.id);
}
```

---

## 🎯 PASO 6: Verificación Final

### Checklist de verificación:

```bash
# 1. ¿GitHub Actions dispara en cada push?
git commit -am "test: auto-deploy"
git push
# → Ve a GitHub Actions y verifica que el workflow se ejecute

# 2. ¿Supabase recibe datos?
# Ve a Supabase → SQL Editor y ejecuta:
SELECT COUNT(*) FROM usuarios;
SELECT COUNT(*) FROM planes;

# 3. ¿Row-Level Security funciona?
# Loguéate como staff en GEMSES360
# → Solo deberías ver tus propios planes

# 4. ¿Códigos PG-* son únicos?
SELECT COUNT(DISTINCT codigo) as unicos, COUNT(*) as total FROM planes;
# Debería dar: unicos = total
```

---

## 📞 SUPPORT: Si algo sale mal

### GitHub Actions no dispara
- Verifica que `COOLIFY_WEBHOOK` y `COOLIFY_TOKEN` estén en Settings → Secrets
- Revisa GitHub Actions → Deploy → Logs

### Migración falla
```bash
# Verificar que Supabase esté listo
curl -H "Authorization: Bearer $SUPABASE_KEY" \
  https://tu-proyecto.supabase.co/rest/v1/usuarios

# Si sale error, espera 5 min y reintenta
```

### RLS no filtra datos
- Verifica que el `usuario_id` sea correcto en la BD
- Asegúrate que `auth.uid()` devuelva el UUID correcto

---

## 🎉 PRÓXIMOS PASOS

Una vez que todo esté funcionando:

1. **Optimización:**
   - Agregar índices adicionales si hay lag
   - Cachear con IndexedDB en el navegador
   - Replicación en tiempo real con WebSockets

2. **Seguridad:**
   - Habilitar HTTPS (ya está en gemses360.metacalidad.cloud)
   - Implementar 2FA
   - Auditoría de accesos

3. **Escalabilidad:**
   - Agregar más hospitales
   - Soporte para multiple tenants
   - Analytics / Power BI

---

**¿Dudas?** Pregunta en el chat. Estoy aquí para ayudarte.

**Status:** ✅ Auto-deploy configurado · ✅ BD centralizada lista · ✅ Migración lista
