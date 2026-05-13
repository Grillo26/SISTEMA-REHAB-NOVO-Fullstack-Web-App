# Centro de Rehabilitación NOVO - Sistema de Gestión

Sistema integral para la gestión de centros de rehabilitación de farmacodependencia (Bolivia).  
Diseñado para reemplazar los procesos manuales (papel) y optimizar la operación diaria: admisión, planes terapéuticos, asistencia, llamadas, limpieza, disciplina, farmacia, evaluaciones y reportes.

---

## 📌 Tabla de Contenidos

- [Contexto y Alcance](#contexto-y-alcance)
- [Arquitectura General](#arquitectura-general)
- [Módulos Funcionales](#módulos-funcionales)
- [Tecnologías Utilizadas](#tecnologías-utilizadas)
- [Modelo de Datos (Base de Datos)](#modelo-de-datos-base-de-datos)
- [Instalación y Configuración](#instalación-y-configuración)
  - [Backend (Spring Boot)](#backend-spring-boot)
  - [Frontend (Angular)](#frontend-angular)
- [Autenticación y Seguridad (JWT)](#autenticación-y-seguridad-jwt)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Contribución y Roadmap](#contribución-y-roadmap)

---

## Contexto y Alcance

El Centro de Rehabilitación NOVO (Bolivia) atiende pacientes con farmacodependencia en modalidades **residencial** y **ambulatorio** (6 fases escalonadas). El sistema resuelve los procesos actualmente manuales:

- Registro de pacientes, contactos de emergencia y documentos legales.
- Evaluación clínica y socio‑familiar, historial de consumo.
- Plan terapéutico individual (objetivos, responsables, versionado).
- Control de asistencia a actividades y comedor (conteo de personal/voluntarios).
- Aplicación de tests estandarizados (ASSIST, BDI‑II, etc.).
- Gestión de llamadas telefónicas por etapa (minutos configurables + saldo).
- Supervisión de limpieza (individual y por habitaciones).
- Sistema disciplinario (tickets → contratos).
- Farmacia (prescripciones, stock, administración de dosis).
- Dashboard y reportes exportables (Excel/PDF).

---

## Arquitectura General

- **Frontend**: Angular 17+ (SPA).
- **Backend**: Spring Boot 3.x (API REST, arquitectura por capas: Controller → Service → Repository).
- **Base de datos**: PostgreSQL 15+.
- **Migraciones**: Flyway (scripts versionados).
- **Seguridad**: Spring Security + JWT (autenticación stateless).
- **Comunicación**: JSON sobre HTTP, documentación con OpenAPI (Swagger).

---

## Módulos Funcionales

| ID  | Módulo                              | Descripción breve                                                                          |
| --- | ----------------------------------- | ------------------------------------------------------------------------------------------ |
| M01 | Admisión y Gestión de Pacientes     | Datos personales, contactos, historial de consumo, documentos, asignación de etapa inicial |
| M02 | Plan Terapéutico Individual         | Objetivos (SOAP), profesionales responsables, versionado                                   |
| M03 | Control de Asistencia y Actividades | Registro de asistencia (actividades + comedor) por etapa y régimen                         |
| M04 | Evaluaciones y Tests                | Tests estandarizados, puntuación automática, gráficos de evolución                         |
| M05 | Evolución Clínica y Bitácora        | Notas SOAP (psicólogos) + comentarios libres (voluntarios)                                 |
| M06 | Farmacia                            | Prescripciones, stock de medicamentos, administración de dosis                             |
| M07 | Ingresos, Salidas y Altas           | Control de períodos activos, egresos, reingresos                                           |
| M08 | Reportes y Dashboard                | KPIs, alertas (medicamentos, contratos), exportación Excel/PDF                             |
| M09 | Convivencia y Comunicaciones        | Llamadas (minutos por etapa), limpieza (individual/habitaciones), tickets y contratos      |

---

## Tecnologías Utilizadas

### Backend (Spring Boot)

- Java 17
- Spring Boot 3.4.x
- Spring Web (REST)
- Spring Security + JWT (JJWT 0.12.6)
- Spring Data JPA (Hibernate)
- PostgreSQL Driver
- Flyway (migraciones)
- Lombok
- Spring Boot DevTools
- Validation
- OpenAPI (SpringDoc) – documentación de APIs

### Frontend (Angular)

- Angular 17+
- TypeScript
- Bootstrap / Angular Material (según preferencia)
- HttpClientModule (consumo de API)
- RxJS
- JWT Interceptor

### Infraestructura / Herramientas

- Maven (gestión de dependencias)
- Git / GitHub
- PostgreSQL 15 (local o Docker)

---

## Modelo de Datos (Base de Datos)

El script completo de creación de tablas (versión Flyway) se encuentra en  
`src/main/resources/db/migration/V1__create_tables.sql`.  
Incluye:

- **Catálogos**: `fase_etapa`, `tipo_documento`, `sustancia`, `actividad`, `item_limpieza`, `habitacion`, etc.
- **Seguridad**: `usuario`, `rol`.
- **M01–M09**: Todas las tablas necesarias para admisión, plan terapéutico, asistencia, farmacia, convivencia, etc.
- **Vistas y funciones**: `vista_paciente_etapa_actual`, `minutos_llamada_restantes(paciente_id)`.

La base está preparada para **futuro multi‑inquilino** (columna `tenant_id` en tablas principales).

---

## Instalación y Configuración

### Requisitos previos

- Java 17+ instalado
- PostgreSQL 15+ instalado y en ejecución
- Node.js 18+ y Angular CLI (`npm install -g @angular/cli`)
- Git (opcional)

### Backend (Spring Boot)

1. **Clonar el repositorio**

   ```bash
   git clone https://github.com/tu-usuario/centro-rehabilitacion-novo.git
   cd centro-rehabilitacion-novo/backend

   ```

2. **Crear la base de datos en PostgreSQL**
   CREATE DATABASE centro_novo_db;

3. **Configurar application.properties (en src/main/resources)**
   spring.datasource.url=jdbc:postgresql://localhost:5432/centro_novo_db
   spring.datasource.username=postgres
   spring.datasource.password=tu_contraseña
   spring.jpa.hibernate.ddl-auto=validate
   spring.flyway.enabled=true

   # ... resto de configuraciones (ver sección anterior)

4. **Configurar application.properties (en src/main/resources)**
   ./mvnw spring-boot:run # Linux/macOS
   mvnw.cmd spring-boot:run # Windows

La API estará disponible en http://localhost:8080.
Documentación Swagger: http://localhost:8080/swagger-ui.html
