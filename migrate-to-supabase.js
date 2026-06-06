/**
 * GEMSES360 Migration: localStorage → Supabase PostgreSQL
 * Usage: node migrate-to-supabase.js
 *
 * ⚠️  IMPORTANTE: Ejecutar DESPUÉS de que Supabase esté listo
 * - Supabase debe tener BD creada
 * - RLS policies configuradas
 * - Hospitales y maestras precargadas
 */

const fs = require('fs');
const https = require('https');
const { v4: uuidv4 } = require('uuid');

// ============ CONFIGURACIÓN ============
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://tu-proyecto.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'tu-anon-key';
const LOCAL_STORAGE_FILE = process.env.LOCAL_STORAGE_EXPORT || './localStorage-export.json';

// ============ HELPER: HTTP Request ============
async function supabaseRequest(method, endpoint, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1${endpoint}`);
    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ============ PASO 1: Cargar datos de localStorage ============
async function loadLocalStorageData() {
  console.log('📂 Cargando datos de localStorage...');

  if (!fs.existsSync(LOCAL_STORAGE_FILE)) {
    console.error(`❌ No encontré ${LOCAL_STORAGE_FILE}`);
    console.error('Primero exporta los datos con: JSON.stringify(localStorage) en el navegador');
    process.exit(1);
  }

  const exported = JSON.parse(fs.readFileSync(LOCAL_STORAGE_FILE, 'utf-8'));
  const g360_users = JSON.parse(exported.g360_users || '[]');
  const g360_data = JSON.parse(exported.g360_data || '{}');
  const g360_maestras = JSON.parse(exported.g360_maestras || '{}');

  console.log(`✅ Cargados: ${g360_users.length} usuarios, ${Object.keys(g360_data).length} datos`);
  return { g360_users, g360_data, g360_maestras };
}

// ============ PASO 2: Migrar Usuarios ============
async function migrateUsers(users) {
  console.log('\n👥 Migrando usuarios...');

  for (const user of users) {
    const usuario = {
      id: uuidv4(),
      email: user.email,
      nombre: user.name || user.email,
      rol: user.rol || 'staff',
      rol_org: user.rolOrg,
      hospital_id: user.hospital_id, // Asume que ya existe
      cargo: user.cargo,
      area: user.area,
      onboarded: user.onboarded || false,
      activo: true
    };

    const result = await supabaseRequest('POST', '/usuarios', usuario);
    if (result.status === 201) {
      console.log(`  ✅ ${user.email}`);
    } else {
      console.log(`  ⚠️  ${user.email}: ${result.status}`);
    }
  }
}

// ============ PASO 3: Migrar Planes ============
async function migratePlans(data, users) {
  console.log('\n📋 Migrando planes de gestión...');

  let contador = 0;
  for (const [email, userData] of Object.entries(data)) {
    const user = users.find(u => u.email === email);
    if (!user) {
      console.log(`  ⚠️  Usuario ${email} no encontrado`);
      continue;
    }

    const planes = userData.planes || [];
    for (const plan of planes) {
      const planMigrado = {
        id: uuidv4(),
        codigo: plan.codigo, // PG-HIESC-2024-001 (debe ser UNIQUE)
        nombre: plan.nombre,
        usuario_id: user.id, // Referencia al usuario migrado
        hospital_id: user.hospital_id,
        institucion: plan.institucion,
        unidad_servicio: plan.unidad_servicio,
        autor_email: email,
        cargo_autor: plan.cargo_autor,
        profesion: plan.profesion,
        nivel_plan: plan.nivel_plan,
        periodo_gestion: plan.periodo_gestion,
        info: plan.info || {},
        autodiag: plan.autodiag || {},
        pestel: plan.pestel || {},
        pest_items: plan.pest_items || [],
        foda: plan.foda || {},
        crono: plan.crono || [],
        monitoreo: plan.monitoreo || [],
        paso_actual: plan.paso_actual || 'info',
        creado_en: plan.creado || new Date().toISOString()
      };

      const result = await supabaseRequest('POST', '/planes', planMigrado);
      if (result.status === 201) {
        console.log(`  ✅ ${plan.codigo}`);
        contador++;
      } else {
        console.log(`  ❌ ${plan.codigo}: ${result.status}`);
      }
    }
  }
  console.log(`Total: ${contador} planes migrados`);
}

// ============ PASO 4: Migrar Indicadores ============
async function migrateIndicators(data, users) {
  console.log('\n📊 Migrando indicadores...');

  let contador = 0;
  for (const [email, userData] of Object.entries(data)) {
    const user = users.find(u => u.email === email);
    if (!user) continue;

    const indicadores = userData.indicadores || [];
    for (const ind of indicadores) {
      const indicador = {
        id: uuidv4(),
        usuario_id: user.id,
        hospital_id: user.hospital_id,
        nombre: ind.nombre,
        tipo: ind.tipo || 'KPI',
        dimension: ind.dimension,
        formula: ind.formula,
        meta: ind.meta,
        responsable: ind.responsable,
        plan_codigo: ind.plan_codigo,
        mediciones: ind.mediciones || [],
        creado_en: new Date().toISOString()
      };

      const result = await supabaseRequest('POST', '/indicadores', indicador);
      if (result.status === 201) {
        contador++;
      }
    }
  }
  console.log(`Total: ${contador} indicadores migrados`);
}

// ============ VALIDACIÓN POST-MIGRACIÓN ============
async function validateMigration() {
  console.log('\n🔍 Validando migración...');

  const usuarios = await supabaseRequest('GET', '/usuarios?limit=100');
  const planes = await supabaseRequest('GET', '/planes?limit=100');
  const indicadores = await supabaseRequest('GET', '/indicadores?limit=100');

  console.log(`✅ Usuarios: ${usuarios.data?.length || 0}`);
  console.log(`✅ Planes: ${planes.data?.length || 0}`);
  console.log(`✅ Indicadores: ${indicadores.data?.length || 0}`);

  // Verificar códigos únicos
  const planes_arr = planes.data || [];
  const codigos = planes_arr.map(p => p.codigo);
  const unicos = new Set(codigos);
  if (codigos.length === unicos.size) {
    console.log('✅ Códigos PG-* son únicos globalmente');
  } else {
    console.log('❌ ⚠️  Hay códigos duplicados!');
  }
}

// ============ MAIN ============
async function main() {
  try {
    console.log('🚀 GEMSES360: Migración localStorage → Supabase\n');

    // Cargar datos
    const { g360_users, g360_data, g360_maestras } = await loadLocalStorageData();

    // Migrar
    await migrateUsers(g360_users);
    await migratePlans(g360_data, g360_users);
    await migrateIndicators(g360_data, g360_users);

    // Validar
    await validateMigration();

    console.log('\n✅ MIGRACIÓN COMPLETADA');
    console.log('📍 Siguiente paso: Refactorizar GEMSES360 para usar la API');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
