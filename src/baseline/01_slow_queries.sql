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
PROMPT [BASELINE] Ejecutando consulta con antipatron TRUNC()...
PROMPT ========================================================

SELECT /*+ GATHER_PLAN_STATISTICS */
    status,
    COUNT(*) AS total_count,
    SUM(amount) AS total_amount
FROM ledger_transactions
WHERE TRUNC(transaction_date) = TO_DATE('2026-05-15', 'YYYY-MM-DD')
  AND status = 'COMPLETED'
GROUP BY status;

PROMPT
PROMPT ========================================================
PROMPT [BASELINE] Plan de Ejecucion Real (DBMS_XPLAN)
PROMPT ========================================================

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST +BYTES'));

EXIT;
