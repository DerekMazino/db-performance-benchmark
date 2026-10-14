# ⚡ Database Performance Benchmarking & Refactoring Suite

[![Database: Oracle 23ai Free](https://img.shields.io/badge/Database-Oracle%2023ai%20Free-red.svg)](#)
[![Tech: PL/SQL / SQL Tuning](https://img.shields.io/badge/Tech-PL%2FSQL%20%7C%20CBO%20Tuning-blue.svg)](#)
[![Workflow: Git Flow](https://img.shields.io/badge/Workflow-Git%20Flow-orange.svg)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Un laboratorio reproducible de ingeniería de bases de datos de alto rendimiento enfocado en diagnóstico de cuellos de botella reales, análisis de planes de ejecución (`DBMS_XPLAN`), optimización de CBO y procesamiento por lotes sobre un **dataset transaccional de 10,000,000 de registros**.

---

## 🎯 Resumen Ejecutivo & Resultados Reales

### Benchmark 1: Consulta Transaccional (Sargabilidad e Indexación)
- **Problema:** Consulta de cierre diario escaneando 10M de registros debido a función envolvente `TRUNC()` en predicados.
- **Solución:** Reescritura sargable por rango de fechas + Índice Compuesto de Cobertura (`transaction_date, status, amount`).

| Métrica | Baseline (No Sargable / FTS) | Refactorizado (Covering Index) | Impacto / Reducción |
| :--- | :--- | :--- | :--- |
| **Tiempo de Ejecución (`A-Time`)** | **13.60 segundos** | **0.01 segundos** | **99.9% (1,360x más rápido)** |
| **I/O Lógico (`Consistent Gets / Buffers`)**| **157,000 bloques** | **67 bloques** | **99.95% menos estrés en RAM** |
| **I/O Físico (`Physical Reads`)** | **157,000 bloques** | **0 bloques** | **Eliminación total de I/O de disco** |
| **Ruta de Acceso CBO** | `TABLE ACCESS FULL` | `INDEX RANGE SCAN` | Acceso directo a árbol B-Tree |
| **Costo CBO** | 43,749 | 69 | Reducción drástica de CPU |

---

### Benchmark 2: Procesamiento Masivo por Lotes (PL/SQL Batch Processing)
- **Problema:** Conciliación de 100,000 registros pendientes ejecutada mediante cursor explícito fila a fila (*slow-by-slow*), generando sobrecarga crítica de cambios de contexto (*Context Switching*).
- **Solución:** Extracción vectorizada con `BULK COLLECT LIMIT 5000`, ejecución masiva atómica con `FORALL` y aislamiento de excepciones mediante `SAVE EXCEPTIONS` y tabla de auditoría.

| Métrica | Baseline (Cursor Fila a Fila) | Optimizado (`BULK COLLECT` + `FORALL`) | Impacto / Mejora |
| :--- | :--- | :--- | :--- |
| **Tiempo de Ejecución de CPU** | **21.51 segundos** | **9.00 segundos** | **58.1% de reducción (2.39x throughput)** |
| **Context Switches (PL/SQL $\leftrightarrow$ SQL)** | ~100,000 llamadas | **20 llamadas** | Reducción del **99.98%** en llamadas |
| **Resiliencia Operativa** | Aborto de batch o loop lento | Segregación aislada de errores | 25 fallos auditados sin interrumpir el lote |

---

## 🧱 Modelo de Datos y Distribución Sintética (10M Registros)

```mermaid
erDiagram
    ACCOUNTS ||--o{ LEDGER_TRANSACTIONS : processes
    LEDGER_TRANSACTIONS ||--o{ BATCH_ERROR_LOG : audits
    
    ACCOUNTS {
        NUMBER account_id PK
        VARCHAR2 account_number UK
        VARCHAR2 account_type
        NUMBER current_balance
        TIMESTAMP created_at
    }

    LEDGER_TRANSACTIONS {
        NUMBER transaction_id PK
        NUMBER account_id FK
        TIMESTAMP transaction_date
        VARCHAR2 transaction_type
        NUMBER amount
        VARCHAR2 status
        VARCHAR2 payload_metadata
        TIMESTAMP created_at
    }

    BATCH_ERROR_LOG {
        NUMBER error_id PK
        NUMBER transaction_id
        NUMBER error_code
        VARCHAR2 error_message
        TIMESTAMP failed_at
    }

### Ingeniería del dataset sintético (sesgo y realismo)

- **Principio de Pareto (80/20) en cuentas:** concentra el 80 % del volumen transaccional en un 20 % de cuentas activas mediante distribuciones de potencia (`POWER(DBMS_RANDOM.VALUE(0, 1), 3)`), desafiando las estimaciones de cardinalidad del CBO.
- **Cardinalidad de estados asimétrica:** `COMPLETED` (90 %), `PENDING` (7 %), `FAILED` (2 %), `FLAGGED_FRAUD` (1 %).
- **Carga de alta velocidad:** generación de 10M de filas en menos de 60 s usando Direct-Path Insert (`INSERT /*+ APPEND */`) con tablas en modo `NOLOGGING`.

## 🛠️ Reproducibilidad en local (Docker y macOS)

### 1. Levantar el contenedor Oracle Database 23ai Free

```bash
docker compose -f docker/docker-compose.yml up -d
```

### 2. Inicializar el esquema y generar 10M de registros sintéticos

```bash
docker exec -i oracle-23ai-benchmark sqlplus -S / as sysdba < docker/init/01_schema_baseline.sql
docker exec -i oracle-23ai-benchmark sqlplus -S / as sysdba < docker/init/02_seed_generator.sql
```

### 3. Preparar la auditoría para las pruebas batch

```bash
docker exec -i oracle-23ai-benchmark sqlplus -S 'BENCHMARK_USER/Benchmark2026!@localhost:1521/FREEPDB1' < src/baseline/00_setup_audit.sql
```

### 4. Ejecutar los benchmarks

```bash
docker exec -i oracle-23ai-benchmark sqlplus -S 'BENCHMARK_USER/Benchmark2026!@localhost:1521/FREEPDB1' < src/baseline/01_slow_queries.sql
docker exec -i oracle-23ai-benchmark sqlplus -S 'BENCHMARK_USER/Benchmark2026!@localhost:1521/FREEPDB1' < src/optimized/01_fast_queries.sql
docker exec -i oracle-23ai-benchmark sqlplus -S 'BENCHMARK_USER/Benchmark2026!@localhost:1521/FREEPDB1' < src/baseline/02_slow_batch.plsql
docker exec -i oracle-23ai-benchmark sqlplus -S 'BENCHMARK_USER/Benchmark2026!@localhost:1521/FREEPDB1' < src/optimized/02_fast_batch.plsql
```

## 👤 Autor

**Juan Camilo Marín García**

*SQL Data Engineer & Database Specialist*