SET ECHO OFF;
SET FEEDBACK OFF;
SET TIMING ON;
SET LINESIZE 250;
SET PAGESIZE 1000;
SET TRIMOUT ON;
SET TRIMSPOOL ON;

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = BENCHMARK_USER;
ALTER SESSION SET STATISTICS_LEVEL = ALL;

PROMPT ========================================================
PROMPT [BASELINE] Reporte analitico sobre tabla monolitica (sin particionar)
PROMPT ========================================================

SELECT /*+ GATHER_PLAN_STATISTICS MONITOR */
    transaction_type,
    status,
    COUNT(*) AS total_tx,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount
FROM ledger_transactions
WHERE transaction_date >= TO_DATE('2026-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
  AND transaction_date <  TO_DATE('2026-02-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
GROUP BY transaction_type, status
ORDER BY transaction_type, status;

PROMPT
PROMPT ========================================================
PROMPT [BASELINE] Plan de Ejecucion (DBMS_XPLAN)
PROMPT ========================================================

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST +PARTITION'));

EXIT;
