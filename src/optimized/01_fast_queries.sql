SET ECHO OFF;
SET FEEDBACK OFF;
SET TIMING ON;
SET LINESIZE 250;
SET PAGESIZE 1000;
SET TRIMOUT ON;
SET TRIMSPOOL ON;

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = BENCHMARK_USER;

PROMPT ========================================================
PROMPT [OPTIMIZACION] Creando indice compuesto de cobertura...
PROMPT ========================================================

CREATE INDEX idx_ledger_perf_cover 
ON ledger_transactions (transaction_date, status, amount)
ONLINE;

EXEC DBMS_STATS.GATHER_INDEX_STATS(ownname => 'BENCHMARK_USER', indname => 'IDX_LEDGER_PERF_COVER');

ALTER SESSION SET STATISTICS_LEVEL = ALL;

PROMPT
PROMPT ========================================================
PROMPT [OPTIMIZACION] Ejecutando consulta sargable con rango...
PROMPT ========================================================

SELECT /*+ GATHER_PLAN_STATISTICS */
    status,
    COUNT(*) AS total_count,
    SUM(amount) AS total_amount
FROM ledger_transactions
WHERE transaction_date >= TO_DATE('2026-05-15 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
  AND transaction_date <  TO_DATE('2026-05-16 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
  AND status = 'COMPLETED'
GROUP BY status;

PROMPT
PROMPT ========================================================
PROMPT [OPTIMIZACION] Plan de Ejecucion Optimizado (DBMS_XPLAN)
PROMPT ========================================================

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST +BYTES'));

EXIT;
