-- ======================================================
-- SISTEMA DE GESTIÓN PARA CENTRO DE REHABILITACIÓN NOVO
-- BASE DE DATOS: PostgreSQL 15+
-- AUTOR: Ing. Carlos Enrique Mamani torrez
-- FECHA: 2026-05-01
-- ======================================================

-- Extensión para UUID (opcional, si se usan)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ======================================================
-- 1. TABLAS MAESTRAS Y CATÁLOGOS (compartidas)
-- ======================================================

-- Catálogo de fases y etapas (M01-04)
CREATE TABLE fase_etapa (
                            id BIGSERIAL PRIMARY KEY,
                            tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                            fase_nombre VARCHAR(50) NOT NULL, -- 'Fase 1', 'Fase 2', 'Programa Reducido'
                            etapa_nombre VARCHAR(50) NOT NULL, -- 'Ev', '1', '2', ..., 'PR-1', 'PR-2'
                            orden INT NOT NULL, -- orden secuencial
                            regimen VARCHAR(20) NOT NULL CHECK (regimen IN ('RESIDENCIAL', 'AMBULATORIO')),
                            minutos_llamada_semana INT DEFAULT 0,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            UNIQUE(tenant_id, fase_nombre, etapa_nombre)
);

-- Catálogo de tipos de documento (M01-03)
CREATE TABLE tipo_documento (
                                id BIGSERIAL PRIMARY KEY,
                                tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                                nombre VARCHAR(100) NOT NULL,
                                descripcion TEXT,
                                requiere_fecha_vencimiento BOOLEAN DEFAULT FALSE,
                                obligatorio_admision BOOLEAN DEFAULT FALSE,
                                activo BOOLEAN DEFAULT TRUE,
                                UNIQUE(tenant_id, nombre)
);

-- Catálogo de sustancias (M01-02)
CREATE TABLE sustancia (
                           id BIGSERIAL PRIMARY KEY,
                           tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                           nombre VARCHAR(100) NOT NULL,
                           tipo VARCHAR(50), -- estimulante, depresor, opioide, etc.
                           activo BOOLEAN DEFAULT TRUE,
                           UNIQUE(tenant_id, nombre)
);

-- Catálogo de actividades (M03)
CREATE TABLE actividad (
                           id BIGSERIAL PRIMARY KEY,
                           tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                           nombre VARCHAR(100) NOT NULL,
                           tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('Terapia', 'Taller', 'Comedor', 'Deporte', 'Otro')),
                           duracion_minutos INT NOT NULL,
                           hora_inicio TIME NOT NULL,
                           dias_semana VARCHAR(20)[] NOT NULL, -- ['LUN', 'MAR', ...]
                           responsable_id BIGINT, -- FK a usuario (se define después)
                           regimen_aplicable VARCHAR(20) CHECK (regimen_aplicable IN ('RESIDENCIAL', 'AMBULATORIO', 'AMBOS')),
                           created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Relación actividad-etapas (muchos a muchos)
CREATE TABLE actividad_etapa (
                                 actividad_id BIGINT NOT NULL,
                                 etapa_id BIGINT NOT NULL,
                                 PRIMARY KEY (actividad_id, etapa_id)
);

-- Ítems de limpieza por habitación (M09)
CREATE TABLE item_limpieza (
                               id BIGSERIAL PRIMARY KEY,
                               tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                               nombre VARCHAR(100) NOT NULL, -- "Piso barrido", "Baño desinfectado"
                               orden INT DEFAULT 0,
                               activo BOOLEAN DEFAULT TRUE
);

-- Habitaciones (M09)
CREATE TABLE habitacion (
                            id BIGSERIAL PRIMARY KEY,
                            tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                            nombre VARCHAR(50) NOT NULL, -- "Habitación 1", "Habitación 2"
                            capacidad INT DEFAULT 4,
                            activo BOOLEAN DEFAULT TRUE,
                            UNIQUE(tenant_id, nombre)
);

-- ======================================================
-- 2. USUARIOS Y ROLES (seguridad)
-- ======================================================

CREATE TABLE rol (
                     id BIGSERIAL PRIMARY KEY,
                     nombre VARCHAR(50) UNIQUE NOT NULL -- ADMIN, PSICOLOGO, MEDICO, TRABAJADOR_SOCIAL, VOLUNTARIO, COORDINADOR
);

CREATE TABLE usuario (
                         id BIGSERIAL PRIMARY KEY,
                         tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                         username VARCHAR(100) UNIQUE NOT NULL,
                         password_hash VARCHAR(255) NOT NULL,
                         email VARCHAR(150),
                         nombres VARCHAR(100),
                         apellidos VARCHAR(100),
                         rol_id BIGINT NOT NULL REFERENCES rol(id),
                         activo BOOLEAN DEFAULT TRUE,
                         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================
-- 3. MÓDULO M01 – ADMISIÓN Y GESTIÓN DE PACIENTES
-- ======================================================

CREATE TABLE paciente (
                          id BIGSERIAL PRIMARY KEY,
                          tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                          numero_expediente VARCHAR(20) UNIQUE NOT NULL,
                          ci VARCHAR(20) NOT NULL,
                          nombre_completo VARCHAR(150) NOT NULL,
                          fecha_nacimiento DATE NOT NULL,
                          sexo CHAR(1) CHECK (sexo IN ('M', 'F', 'O')),
                          estado_civil VARCHAR(30),
                          nacionalidad VARCHAR(50) DEFAULT 'Boliviana',
                          ocupacion VARCHAR(100),
                          direccion TEXT,
                          telefono VARCHAR(20),
                          email VARCHAR(150),
                          fotografia_url TEXT,
                          activo BOOLEAN DEFAULT TRUE,
                          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_paciente_ci ON paciente(ci);
CREATE INDEX idx_paciente_nombre ON paciente(nombre_completo);

-- Contactos de emergencia (hasta 3 por paciente)
CREATE TABLE contacto_emergencia (
                                     id BIGSERIAL PRIMARY KEY,
                                     paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                     nombre VARCHAR(100) NOT NULL,
                                     parentesco VARCHAR(50) NOT NULL,
                                     telefono VARCHAR(20) NOT NULL,
                                     orden INT DEFAULT 1
);

-- Historial de consumo (M01-02)
CREATE TABLE consumo_sustancia (
                                   id BIGSERIAL PRIMARY KEY,
                                   paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                   sustancia_id BIGINT NOT NULL REFERENCES sustancia(id),
                                   frecuencia VARCHAR(30) CHECK (frecuencia IN ('Diaria', 'Semanal', 'Ocasional', 'En desintoxicación')),
                                   via_administracion VARCHAR(30) CHECK (via_administracion IN ('Oral', 'Inhalada', 'Fumada', 'Inyectada')),
                                   edad_inicio INT,
                                   anos_consumo DECIMAL(4,1),
                                   fecha_ultimo_consumo DATE,
                                   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tratamientos previos
CREATE TABLE tratamiento_previo (
                                    id BIGSERIAL PRIMARY KEY,
                                    paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                    institucion VARCHAR(150),
                                    fecha_inicio DATE,
                                    fecha_fin DATE,
                                    resultado VARCHAR(50) CHECK (resultado IN ('Alta', 'Abandono', 'Fracaso')),
                                    documento_url TEXT,
                                    observaciones TEXT
);

-- Evaluación socio-familiar (M01-02)
CREATE TABLE evaluacion_socio_familiar (
                                           id BIGSERIAL PRIMARY KEY,
                                           paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                           fecha_evaluacion DATE NOT NULL DEFAULT CURRENT_DATE,
                                           composicion_familiar TEXT,
                                           ingreso_mensual NUMERIC(10,2),
                                           tipo_vivienda VARCHAR(50),
                                           tiene_hacinamiento BOOLEAN,
                                           redes_apoyo TEXT,
                                           violencia_tipo VARCHAR(100),
                                           situacion_legal TEXT,
                                           trabajador_social_id BIGINT REFERENCES usuario(id),
                                           finalizado BOOLEAN DEFAULT FALSE
);

-- Evaluación de salud general (M01-02)
CREATE TABLE evaluacion_salud (
                                  id BIGSERIAL PRIMARY KEY,
                                  paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                  fecha DATE DEFAULT CURRENT_DATE,
                                  enfermedades_cronicas TEXT,
                                  alergias TEXT,
                                  medicacion_actual TEXT,
                                  peso NUMERIC(5,2),
                                  talla NUMERIC(5,2),
                                  imc NUMERIC(5,2) GENERATED ALWAYS AS (peso / (talla * talla)) STORED,
                                  medico_id BIGINT REFERENCES usuario(id),
                                  finalizado BOOLEAN DEFAULT FALSE
);

-- Consentimientos y documentos (M01-03)
CREATE TABLE documento (
                           id BIGSERIAL PRIMARY KEY,
                           tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                           paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                           tipo_documento_id BIGINT NOT NULL REFERENCES tipo_documento(id),
                           nombre_archivo VARCHAR(255) NOT NULL,
                           ruta_archivo TEXT NOT NULL,
                           hash_sha256 VARCHAR(64),
                           fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                           usuario_carga_id BIGINT REFERENCES usuario(id),
                           fecha_vencimiento DATE,
                           activo BOOLEAN DEFAULT TRUE,
                           observaciones TEXT
);

-- Asignación de fase y etapa actual del paciente (M01-04)
CREATE TABLE paciente_etapa_historial (
                                          id BIGSERIAL PRIMARY KEY,
                                          paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                          etapa_id BIGINT NOT NULL REFERENCES fase_etapa(id),
                                          fecha_inicio DATE NOT NULL,
                                          fecha_fin DATE,
                                          motivo TEXT,
                                          usuario_id BIGINT REFERENCES usuario(id),
                                          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice para obtener etapa actual (fecha_fin NULL)
CREATE INDEX idx_paciente_etapa_activa ON paciente_etapa_historial(paciente_id) WHERE fecha_fin IS NULL;

-- ======================================================
-- 4. MÓDULO M02 – PLAN TERAPÉUTICO INDIVIDUAL
-- ======================================================

CREATE TABLE plan_terapeutico (
                                  id BIGSERIAL PRIMARY KEY,
                                  paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                  version INT NOT NULL DEFAULT 1,
                                  etapa_id BIGINT REFERENCES fase_etapa(id), -- etapa asociada al plan
                                  fecha_creacion DATE NOT NULL DEFAULT CURRENT_DATE,
                                  activo BOOLEAN DEFAULT TRUE,
                                  psicologo_referente_id BIGINT REFERENCES usuario(id),
                                  medico_id BIGINT REFERENCES usuario(id),
                                  trabajador_social_id BIGINT REFERENCES usuario(id),
                                  observaciones TEXT,
                                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE objetivo_terapeutico (
                                      id BIGSERIAL PRIMARY KEY,
                                      plan_id BIGINT NOT NULL REFERENCES plan_terapeutico(id) ON DELETE CASCADE,
                                      descripcion TEXT NOT NULL,
                                      tipo VARCHAR(50) CHECK (tipo IN ('psicológico', 'médico', 'social', 'conductual')),
                                      fecha_limite DATE,
                                      criterio_logro TEXT,
                                      estado VARCHAR(30) DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'EN_PROGRESO', 'LOGRADO', 'NO_LOGRADO')),
                                      fecha_logro DATE,
                                      observacion_logro TEXT,
                                      orden INT DEFAULT 0,
                                      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Historial de cambios de objetivo (auditoría simple)
CREATE TABLE objetivo_historial (
                                    id BIGSERIAL PRIMARY KEY,
                                    objetivo_id BIGINT NOT NULL REFERENCES objetivo_terapeutico(id) ON DELETE CASCADE,
                                    campo_modificado VARCHAR(50),
                                    valor_anterior TEXT,
                                    valor_nuevo TEXT,
                                    usuario_id BIGINT REFERENCES usuario(id),
                                    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================
-- 5. MÓDULO M03 – ASISTENCIA Y ACTIVIDADES
-- ======================================================

CREATE TABLE asistencia (
                            id BIGSERIAL PRIMARY KEY,
                            paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                            actividad_id BIGINT NOT NULL REFERENCES actividad(id),
                            fecha DATE NOT NULL,
                            estado VARCHAR(30) NOT NULL CHECK (estado IN ('PRESENTE', 'AUSENTE_JUSTIFICADO', 'AUSENTE_INJUSTIFICADO')),
                            observacion TEXT,
                            usuario_registro_id BIGINT REFERENCES usuario(id),
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            UNIQUE(paciente_id, actividad_id, fecha)
);

-- Registro especial de comedor (conteo de personal)
CREATE TABLE comedor_registro (
                                  id BIGSERIAL PRIMARY KEY,
                                  actividad_id BIGINT NOT NULL REFERENCES actividad(id),
                                  fecha DATE NOT NULL,
                                  voluntarios_cantidad INT DEFAULT 0,
                                  personal_cantidad INT DEFAULT 0,
                                  otros_cantidad INT DEFAULT 0,
                                  observaciones TEXT,
                                  usuario_registro_id BIGINT REFERENCES usuario(id),
                                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                  UNIQUE(actividad_id, fecha)
);

-- ======================================================
-- 6. MÓDULO M04 – TESTS Y EVALUACIONES
-- ======================================================

CREATE TABLE test_cabecera (
                               id BIGSERIAL PRIMARY KEY,
                               tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                               nombre VARCHAR(100) NOT NULL,
                               descripcion TEXT,
                               tipo VARCHAR(50),
                               escala_min INT,
                               escala_max INT,
                               instrucciones TEXT,
                               activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE test_pregunta (
                               id BIGSERIAL PRIMARY KEY,
                               test_id BIGINT NOT NULL REFERENCES test_cabecera(id) ON DELETE CASCADE,
                               texto TEXT NOT NULL,
                               orden INT NOT NULL,
                               tipo_respuesta VARCHAR(30) CHECK (tipo_respuesta IN ('ESCALA', 'OPCION_MULTIPLE', 'NUMERICO')),
                               opciones_json JSONB -- almacena opciones y valores
);

CREATE TABLE test_aplicacion (
                                 id BIGSERIAL PRIMARY KEY,
                                 paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                 test_id BIGINT NOT NULL REFERENCES test_cabecera(id),
                                 fecha_aplicacion DATE NOT NULL DEFAULT CURRENT_DATE,
                                 puntuacion_total INT,
                                 interpretacion VARCHAR(50), -- leve, moderado, severo
                                 usuario_id BIGINT REFERENCES usuario(id),
                                 observaciones TEXT,
                                 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Respuestas detalladas del test
CREATE TABLE test_respuesta (
                                id BIGSERIAL PRIMARY KEY,
                                aplicacion_id BIGINT NOT NULL REFERENCES test_aplicacion(id) ON DELETE CASCADE,
                                pregunta_id BIGINT NOT NULL REFERENCES test_pregunta(id),
                                respuesta_valor INT, -- valor numérico
                                respuesta_texto TEXT,
                                UNIQUE(aplicacion_id, pregunta_id)
);

-- ======================================================
-- 7. MÓDULO M06 – FARMACIA
-- ======================================================

CREATE TABLE medicamento (
                             id BIGSERIAL PRIMARY KEY,
                             tenant_id VARCHAR(50) DEFAULT 'default' NOT NULL,
                             nombre_comercial VARCHAR(150) NOT NULL,
                             principio_activo VARCHAR(150),
                             concentracion VARCHAR(50),
                             forma_farmaceutica VARCHAR(50),
                             unidad_medida VARCHAR(20),
                             es_controlado BOOLEAN DEFAULT FALSE,
                             activo BOOLEAN DEFAULT TRUE,
                             UNIQUE(tenant_id, nombre_comercial)
);

CREATE TABLE lote_medicamento (
                                  id BIGSERIAL PRIMARY KEY,
                                  medicamento_id BIGINT NOT NULL REFERENCES medicamento(id),
                                  lote VARCHAR(100),
                                  fecha_vencimiento DATE NOT NULL,
                                  cantidad_inicial INT NOT NULL,
                                  cantidad_actual INT NOT NULL,
                                  proveedor VARCHAR(150),
                                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prescripcion (
                              id BIGSERIAL PRIMARY KEY,
                              paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                              medicamento_id BIGINT NOT NULL REFERENCES medicamento(id),
                              medico_id BIGINT NOT NULL REFERENCES usuario(id),
                              dosis VARCHAR(100) NOT NULL,
                              frecuencia VARCHAR(100) NOT NULL,
                              duracion_dias INT,
                              fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
                              fecha_fin DATE,
                              via_administracion VARCHAR(50),
                              instrucciones TEXT,
                              estado VARCHAR(30) DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'SUSPENDIDA', 'FINALIZADA')),
                              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE administracion_medicamento (
                                            id BIGSERIAL PRIMARY KEY,
                                            prescripcion_id BIGINT NOT NULL REFERENCES prescripcion(id),
                                            fecha_hora TIMESTAMP NOT NULL,
                                            estado VARCHAR(30) CHECK (estado IN ('ADMINISTRADA', 'RECHAZADA', 'OMITIDA')),
                                            observacion TEXT,
                                            usuario_id BIGINT REFERENCES usuario(id),
                                            segundo_usuario_id BIGINT REFERENCES usuario(id), -- para controlados
                                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================
-- 8. MÓDULO M07 – INGRESOS, SALIDAS Y ALTAS
-- ======================================================

CREATE TABLE ingreso_egreso (
                                id BIGSERIAL PRIMARY KEY,
                                paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                fecha_inicio DATE NOT NULL,
                                fecha_fin DATE, -- NULL si activo
                                modalidad VARCHAR(30) NOT NULL CHECK (modalidad IN ('RESIDENCIAL', 'AMBULATORIO')),
                                tipo_egreso VARCHAR(30) CHECK (tipo_egreso IN ('ALTA_TERAPEUTICA', 'ALTA_VOLUNTARIA', 'ABANDONO', 'RECAIDA')),
                                motivo_egreso TEXT,
                                profesional_id BIGINT REFERENCES usuario(id),
                                anulado BOOLEAN DEFAULT FALSE,
                                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ingreso_egreso_activo ON ingreso_egreso(paciente_id) WHERE fecha_fin IS NULL AND anulado = FALSE;

-- ======================================================
-- 9. MÓDULO M05 – EVOLUCIÓN CLÍNICA Y BITÁCORA
-- ======================================================

CREATE TABLE nota_evolucion (
                                id BIGSERIAL PRIMARY KEY,
                                paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                tipo_nota VARCHAR(30) NOT NULL CHECK (tipo_nota IN ('CLINICA', 'BITACORA')),
                                subtipo VARCHAR(50), -- psicológica, médica, social (para clínica)
                                contenido TEXT NOT NULL,
                                fecha DATE NOT NULL DEFAULT CURRENT_DATE,
                                usuario_id BIGINT REFERENCES usuario(id),
                                etiquetas VARCHAR(100)[],
                                eliminado BOOLEAN DEFAULT FALSE,
                                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Auditoría de cambios en notas (simplificada)
CREATE TABLE nota_evolucion_audit (
                                      id BIGSERIAL PRIMARY KEY,
                                      nota_id BIGINT NOT NULL REFERENCES nota_evolucion(id) ON DELETE CASCADE,
                                      contenido_anterior TEXT,
                                      contenido_nuevo TEXT,
                                      usuario_id BIGINT REFERENCES usuario(id),
                                      fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================
-- 10. MÓDULO M09 – GESTIÓN DE CONVIVENCIA Y COMUNICACIONES
-- ======================================================

-- Registro de llamadas
CREATE TABLE llamada (
                         id BIGSERIAL PRIMARY KEY,
                         paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                         contacto_id BIGINT NOT NULL REFERENCES contacto_emergencia(id),
                         duracion_minutos INT NOT NULL CHECK (duracion_minutos > 0),
                         fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                         usuario_registro_id BIGINT REFERENCES usuario(id),
                         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Control semanal de minutos consumidos (vista o tabla agregada)
-- Usaremos una función para calcular saldo en tiempo real, no tabla redundante inicialmente.

-- Limpieza individual
CREATE TABLE limpieza_individual (
                                     id BIGSERIAL PRIMARY KEY,
                                     paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                                     fecha DATE NOT NULL,
                                     estado VARCHAR(20) CHECK (estado IN ('APROBADO', 'NO_APROBADO')),
                                     observacion TEXT,
                                     usuario_id BIGINT REFERENCES usuario(id),
                                     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                     UNIQUE(paciente_id, fecha)
);

-- Limpieza por habitación (checklist)
CREATE TABLE limpieza_habitacion (
                                     id BIGSERIAL PRIMARY KEY,
                                     habitacion_id BIGINT NOT NULL REFERENCES habitacion(id),
                                     fecha DATE NOT NULL,
                                     estado VARCHAR(20) CHECK (estado IN ('LIMPIA', 'NO_LIMPIA')),
                                     observacion TEXT,
                                     usuario_id BIGINT REFERENCES usuario(id),
                                     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                     UNIQUE(habitacion_id, fecha)
);

-- Detalle de ítems no cumplidos (opcional)
CREATE TABLE limpieza_habitacion_incidencia (
                                                id BIGSERIAL PRIMARY KEY,
                                                limpieza_habitacion_id BIGINT NOT NULL REFERENCES limpieza_habitacion(id) ON DELETE CASCADE,
                                                item_limpieza_id BIGINT NOT NULL REFERENCES item_limpieza(id)
);

-- Tickets de disciplina
CREATE TABLE ticket (
                        id BIGSERIAL PRIMARY KEY,
                        paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                        motivo VARCHAR(100) NOT NULL,
                        observacion TEXT,
                        fecha_emision TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        usuario_emision_id BIGINT REFERENCES usuario(id),
                        estado VARCHAR(20) DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'RESUELTO', 'ANULADO')),
                        fecha_resolucion TIMESTAMP,
                        usuario_resolucion_id BIGINT REFERENCES usuario(id)
);

-- Contratos disciplinarios
CREATE TABLE contrato (
                          id BIGSERIAL PRIMARY KEY,
                          paciente_id BIGINT NOT NULL REFERENCES paciente(id) ON DELETE CASCADE,
                          descripcion TEXT NOT NULL,
                          compromisos TEXT,
                          acciones_centro TEXT,
                          fecha_emision DATE NOT NULL DEFAULT CURRENT_DATE,
                          fecha_revision DATE,
                          estado VARCHAR(20) DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'CUMPLIDO', 'INCUMPLIDO')),
                          coordinador_id BIGINT REFERENCES usuario(id),
                          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Relación contrato-tickets (muchos a muchos)
CREATE TABLE contrato_ticket (
                                 contrato_id BIGINT NOT NULL REFERENCES contrato(id) ON DELETE CASCADE,
                                 ticket_id BIGINT NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
                                 PRIMARY KEY (contrato_id, ticket_id)
);

-- ======================================================
-- 11. TABLAS DE AUDITORÍA GENERAL (opcional, simplificado)
-- ======================================================

CREATE TABLE auditoria (
                           id BIGSERIAL PRIMARY KEY,
                           tabla_afectada VARCHAR(50),
                           registro_id BIGINT,
                           accion VARCHAR(20), -- INSERT, UPDATE, DELETE
                           usuario_id BIGINT REFERENCES usuario(id),
                           fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                           datos_anteriores JSONB,
                           datos_nuevos JSONB
);

-- ======================================================
-- 12. FUNCIONES Y VISTAS ÚTILES
-- ======================================================

-- Vista de etapa actual del paciente (simplifica consultas)
CREATE VIEW vista_paciente_etapa_actual AS
SELECT p.id AS paciente_id, p.nombre_completo, ph.etapa_id, fe.fase_nombre, fe.etapa_nombre, fe.regimen
FROM paciente p
         JOIN paciente_etapa_historial ph ON p.id = ph.paciente_id AND ph.fecha_fin IS NULL
         JOIN fase_etapa fe ON ph.etapa_id = fe.id
WHERE p.activo = true;

-- Función para calcular minutos restantes de llamada esta semana
CREATE OR REPLACE FUNCTION minutos_llamada_restantes(p_paciente_id BIGINT)
RETURNS INT AS $$
DECLARE
minutos_asignados INT;
    minutos_usados INT;
BEGIN
    -- Obtener minutos asignados según etapa actual
SELECT fe.minutos_llamada_semana INTO minutos_asignados
FROM paciente_etapa_historial ph
         JOIN fase_etapa fe ON ph.etapa_id = fe.id
WHERE ph.paciente_id = p_paciente_id AND ph.fecha_fin IS NULL;

-- Sumar minutos ya usados esta semana (lunes a domingo actual)
SELECT COALESCE(SUM(duracion_minutos), 0) INTO minutos_usados
FROM llamada
WHERE paciente_id = p_paciente_id
  AND fecha_hora >= date_trunc('week', CURRENT_DATE)
  AND fecha_hora < date_trunc('week', CURRENT_DATE) + INTERVAL '7 days';

RETURN GREATEST(minutos_asignados - minutos_usados, 0);
END;
$$ LANGUAGE plpgsql;

-- ======================================================
-- 13. INSERCIÓN DE DATOS MÍNIMOS (catálogos semilla)
-- ======================================================

-- Roles básicos
INSERT INTO rol (nombre) VALUES ('ADMIN'), ('PSICOLOGO'), ('MEDICO'), ('TRABAJADOR_SOCIAL'), ('VOLUNTARIO'), ('COORDINADOR');

-- Fases y etapas según centro NOVO
INSERT INTO fase_etapa (tenant_id, fase_nombre, etapa_nombre, orden, regimen, minutos_llamada_semana) VALUES
                                                                                                          ('default', 'Fase 1', 'Ev', 1, 'RESIDENCIAL', 0),
                                                                                                          ('default', 'Fase 1', '1', 2, 'RESIDENCIAL', 5),
                                                                                                          ('default', 'Fase 1', '2', 3, 'RESIDENCIAL', 10),
                                                                                                          ('default', 'Fase 1', '3', 4, 'RESIDENCIAL', 15),
                                                                                                          ('default', 'Fase 1', '4', 5, 'RESIDENCIAL', 20),
                                                                                                          ('default', 'Fase 1', '5', 6, 'RESIDENCIAL', 30),
                                                                                                          ('default', 'Fase 1', '6', 7, 'AMBULATORIO', 40),
                                                                                                          ('default', 'Fase 2', '1', 8, 'AMBULATORIO', 30),
                                                                                                          ('default', 'Fase 2', '2', 9, 'AMBULATORIO', 30),
                                                                                                          ('default', 'Programa Reducido', 'PR-1', 10, 'AMBULATORIO', 20),
                                                                                                          ('default', 'Programa Reducido', 'PR-2', 11, 'AMBULATORIO', 20);

-- Tipos de documento mínimos
INSERT INTO tipo_documento (tenant_id, nombre, obligatorio_admision) VALUES
                                                                         ('default', 'Consentimiento informado', true),
                                                                         ('default', 'Fotocopia de CI', true),
                                                                         ('default', 'Certificado de salud', false),
                                                                         ('default', 'Derivación externa', false),
                                                                         ('default', 'Acta de compromiso', false);

-- Sustancias comunes
INSERT INTO sustancia (tenant_id, nombre, tipo) VALUES
                                                    ('default', 'Alcohol', 'depresor'),
                                                    ('default', 'Marihuana', 'cannabinoide'),
                                                    ('default', 'Cocaína', 'estimulante'),
                                                    ('default', 'Pasta base', 'estimulante'),
                                                    ('default', 'Benzodiazepinas', 'depresor'),
                                                    ('default', 'Opioides', 'opioide');

-- Ítems de limpieza
INSERT INTO item_limpieza (tenant_id, nombre, orden) VALUES
                                                         ('default', 'Piso barrido', 1),
                                                         ('default', 'Camas tendidas', 2),
                                                         ('default', 'Baño limpio', 3),
                                                         ('default', 'Basura vacía', 4);

-- Habitaciones
INSERT INTO habitacion (tenant_id, nombre, capacidad) VALUES
                                                          ('default', 'Habitación 1', 4),
                                                          ('default', 'Habitación 2', 4),
                                                          ('default', 'Habitación 3', 4),
                                                          ('default', 'Habitación 4', 4);

-- Actividades mínimas (se requiere responsable_id, que es usuario, aún no insertado. Se puede actualizar después)
INSERT INTO actividad (tenant_id, nombre, tipo, duracion_minutos, hora_inicio, dias_semana, regimen_aplicable) VALUES
                                                                                                                   ('default', 'Terapia grupal', 'Terapia', 60, '09:00', '{"LUN","MIE","VIE"}', 'AMBOS'),
                                                                                                                   ('default', 'Taller de habilidades', 'Taller', 90, '15:00', '{"MAR","JUE"}', 'AMBOS'),
                                                                                                                   ('default', 'Comedor', 'Comedor', 60, '12:30', '{"LUN","MAR","MIE","JUE","VIE","SAB"}', 'RESIDENCIAL'),
                                                                                                                   ('default', 'Deporte', 'Deporte', 60, '17:00', '{"LUN","MIE","VIE"}', 'RESIDENCIAL');

-- Nota: Las relaciones actividad_etapa se insertan según necesidad (por ejemplo, asociar actividades a etapas específicas). Se pueden agregar después.
