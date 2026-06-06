-- ===================== GEMSES360 SCHEMA (PostgreSQL) =====================
-- Ejecutar en Supabase SQL Editor
-- Este schema centraliza todos los datos de múltiples usuarios

-- ===================== 1. USUARIOS =====================
CREATE TABLE usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  rol VARCHAR(20) DEFAULT 'staff', -- 'admin', 'hadmin' (hospital admin), 'staff'
  rol_org VARCHAR(20),
  hospital_id UUID,
  cargo VARCHAR(50),
  area VARCHAR(255),
  onboarded BOOLEAN DEFAULT FALSE,
  activo BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMP DEFAULT NOW(),
  modificado_en TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_rol ON usuarios(rol);
CREATE INDEX idx_usuarios_hospital ON usuarios(hospital_id);

-- ===================== 2. HOSPITALES / IPRESS =====================
CREATE TABLE hospitales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(255) UNIQUE NOT NULL,
  institucion VARCHAR(100), -- 'EsSalud', 'MINSA', etc.
  abreviatura VARCHAR(10) NOT NULL, -- Para código PG-HIESC-2024-001
  region VARCHAR(100),
  ciudad VARCHAR(100),
  activo BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMP DEFAULT NOW(),
  modificado_en TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_hospitales_abreviatura ON hospitales(abreviatura);

-- ===================== 3. PLANES DE GESTIÓN =====================
CREATE TABLE planes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(50) UNIQUE NOT NULL, -- PG-HIESC-2024-001 (GLOBAL UNIQUE)
  nombre VARCHAR(500) NOT NULL,
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  hospital_id UUID REFERENCES hospitales(id),

  -- Metadatos
  institucion VARCHAR(100),
  unidad_servicio VARCHAR(255),
  autor_email VARCHAR(255),
  cargo_autor VARCHAR(50),
  profesion VARCHAR(50),
  nivel_plan VARCHAR(20), -- 'IPRESS', 'IAFAS', 'UGIPRESS'
  periodo_gestion VARCHAR(50),

  -- Contenido (JSON)
  info JSONB DEFAULT '{}',
  autodiag JSONB DEFAULT '{}',
  pestel JSONB DEFAULT '{}',
  pest_items JSONB DEFAULT '[]',
  foda JSONB DEFAULT '{}',
  crono JSONB DEFAULT '[]',
  monitoreo JSONB DEFAULT '[]',

  -- Estado
  paso_actual VARCHAR(20) DEFAULT 'info',
  creado_en TIMESTAMP DEFAULT NOW(),
  modificado_en TIMESTAMP DEFAULT NOW(),
  modificado_por UUID REFERENCES usuarios(id),

  CONSTRAINT fk_planes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

CREATE UNIQUE INDEX idx_planes_codigo ON planes(codigo);
CREATE INDEX idx_planes_usuario ON planes(usuario_id);
CREATE INDEX idx_planes_hospital ON planes(hospital_id);
CREATE INDEX idx_planes_creado ON planes(creado_en DESC);

-- ===================== 4. INDICADORES =====================
CREATE TABLE indicadores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  hospital_id UUID REFERENCES hospitales(id),

  nombre VARCHAR(500) NOT NULL,
  tipo VARCHAR(50) DEFAULT 'KPI', -- 'KPI', 'KRI', 'KCI'
  dimension VARCHAR(50), -- 'Calidad', 'Tiempo', 'Costo', 'Satisfacción'
  perspectiva VARCHAR(50), -- 'Estratégico', 'Misional', 'Soporte'
  formula TEXT,
  unidad VARCHAR(50),
  meta NUMERIC(10,2),
  sentido VARCHAR(20) DEFAULT 'mayor',
  responsable VARCHAR(255),

  -- Vínculo a plan
  plan_codigo VARCHAR(50),

  -- Mediciones
  mediciones JSONB DEFAULT '[]', -- [{fecha, valor, observaciones}]

  creado_en TIMESTAMP DEFAULT NOW(),
  modificado_en TIMESTAMP DEFAULT NOW(),
  modificado_por UUID REFERENCES usuarios(id)
);

CREATE INDEX idx_indicadores_usuario ON indicadores(usuario_id);
CREATE INDEX idx_indicadores_hospital ON indicadores(hospital_id);
CREATE INDEX idx_indicadores_plan ON indicadores(plan_codigo);

-- ===================== 5. TABLAS MAESTRAS (Catálogos) =====================
CREATE TABLE maestras_hospitales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(255) UNIQUE NOT NULL,
  abreviatura VARCHAR(10) NOT NULL,
  institucion VARCHAR(100),
  creado_en TIMESTAMP DEFAULT NOW()
);

CREATE TABLE maestras_cargos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) UNIQUE NOT NULL, -- 'DIRECTOR', 'JEFE_SERVICIO'
  label VARCHAR(255) NOT NULL,
  funcion VARCHAR(255),
  creado_en TIMESTAMP DEFAULT NOW()
);

CREATE TABLE maestras_autodiag (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profesion VARCHAR(50) NOT NULL,
  nivel_plan VARCHAR(20) NOT NULL,
  macro VARCHAR(50), -- 'Estratégico', 'Misional', 'Soporte'
  componente VARCHAR(255),
  criterio_fortaleza TEXT NOT NULL,
  criterio_debilidad TEXT,
  creado_en TIMESTAMP DEFAULT NOW(),
  UNIQUE(profesion, nivel_plan, componente, criterio_fortaleza)
);

CREATE TABLE maestras_pestel (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profesion VARCHAR(50) NOT NULL,
  nivel_plan VARCHAR(20) NOT NULL,
  dimension VARCHAR(50), -- 'Político', 'Económico', 'Social', 'Tecnológico'
  oportunidad TEXT NOT NULL,
  amenaza TEXT,
  creado_en TIMESTAMP DEFAULT NOW(),
  UNIQUE(profesion, nivel_plan, dimension, oportunidad)
);

-- ===================== 6. AUDITORÍA =====================
CREATE TABLE auditoria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios(id),
  tabla VARCHAR(100) NOT NULL,
  registro_id UUID NOT NULL,
  accion VARCHAR(20), -- 'CREATE', 'UPDATE', 'DELETE'
  datos_antiguos JSONB,
  datos_nuevos JSONB,
  creado_en TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_auditoria_tabla ON auditoria(tabla, registro_id);
CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX idx_auditoria_creado ON auditoria(creado_en DESC);

-- ===================== 7. ROW-LEVEL SECURITY (RLS) =====================
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE planes ENABLE ROW LEVEL SECURITY;
ALTER TABLE indicadores ENABLE ROW LEVEL SECURITY;

-- Policy: Staff ve SOLO sus propios planes
CREATE POLICY "staff_own_planes" ON planes
  FOR SELECT
  USING (usuario_id = auth.uid());

-- Policy: Admin de hospital ve todos los planes de su hospital
CREATE POLICY "hadmin_hospital_planes" ON planes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuarios u
      WHERE u.id = auth.uid()
      AND u.rol_org = 'hadmin'
      AND u.hospital_id = planes.hospital_id
    )
  );

-- Policy: Admin global ve todo
CREATE POLICY "admin_all_planes" ON planes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuarios
      WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- Similarmente para indicadores
CREATE POLICY "staff_own_indicadores" ON indicadores
  FOR SELECT
  USING (usuario_id = auth.uid());

CREATE POLICY "hadmin_hospital_indicadores" ON indicadores
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuarios u
      WHERE u.id = auth.uid()
      AND u.rol_org = 'hadmin'
      AND u.hospital_id = indicadores.hospital_id
    )
  );

CREATE POLICY "admin_all_indicadores" ON indicadores
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'admin'
    )
  );

-- ===================== 8. FUNCIÓN: Generar código PG-IPRESS-AÑO-Nº =====================
CREATE OR REPLACE FUNCTION generar_codigo_plan(
  hospital_abreviatura VARCHAR,
  anio INTEGER
)
RETURNS VARCHAR AS $$
DECLARE
  next_numero INTEGER;
  codigo VARCHAR;
BEGIN
  -- Obtener el siguiente número secuencial para este hospital + año
  SELECT COALESCE(
    MAX(CAST(SUBSTRING(codigo FROM LENGTH(codigo)-2) AS INTEGER)),
    0
  ) + 1 INTO next_numero
  FROM planes
  WHERE codigo LIKE hospital_abreviatura || '-' || anio || '-%';

  -- Generar código: PG-HIESC-2024-001
  codigo := 'PG-' || hospital_abreviatura || '-' || anio || '-' || LPAD(next_numero::TEXT, 3, '0');

  RETURN codigo;
END;
$$ LANGUAGE plpgsql;

-- ===================== 9. SEED DATA =====================
-- Insertar hospitales IPRESS de ejemplo
INSERT INTO hospitales (nombre, institucion, abreviatura, region, ciudad) VALUES
  ('Hospital III EsSalud — Cusco', 'EsSalud', 'HIESC', 'Cusco', 'Cusco'),
  ('Hospital II MINSA — Lima', 'MINSA', 'HIML', 'Lima', 'Lima'),
  ('Hospital Privado Metropolitano', 'Privado', 'HPRIM', 'Lima', 'Lima')
ON CONFLICT DO NOTHING;

-- Insertar cargos maestros
INSERT INTO maestras_cargos (key, label, funcion) VALUES
  ('DIRECTOR', 'Director(a) General', 'Planificación estratégica'),
  ('JEFE_SERVICIO', 'Jefe(a) de Servicio', 'Organización táctica'),
  ('COORDINADOR', 'Coordinador(a)', 'Dirección operativa'),
  ('SUPERVISOR', 'Supervisor(a)', 'Control de procesos'),
  ('PROFESIONAL', 'Profesional Asistencial', 'Operación')
ON CONFLICT DO NOTHING;

-- ===================== 10. TRIGGER: Auditoría automática =====================
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO auditoria (usuario_id, tabla, registro_id, accion, datos_antiguos, datos_nuevos)
  VALUES (
    auth.uid(),
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    CASE WHEN TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'CREATE' OR TG_OP = 'UPDATE' THEN row_to_json(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Habilitar auditoría en planes
CREATE TRIGGER audit_planes_trigger
AFTER INSERT OR UPDATE OR DELETE ON planes
FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- ===================== LISTO =====================
-- ✅ Schema completo para GEMSES360 centralizado
-- ✅ RLS habilitado (Row-Level Security)
-- ✅ Índices para performance
-- ✅ Código PG-IPRESS-AÑO-Nº con UNIQUE constraint
-- ✅ Auditoría automática
--
-- Siguiente paso:
-- 1. Crear proyecto en Supabase.com
-- 2. Copiar/pegar este SQL en SQL Editor
-- 3. Ejecutar migrate-to-supabase.js
-- 4. Refactorizar GEMSES360 para usar la API REST de Supabase
