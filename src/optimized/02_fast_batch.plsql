SET SERVEROUTPUT ON;
SET TIMING ON;
SET ECHO OFF;
SET FEEDBACK OFF;

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = BENCHMARK_USER;

PROMPT ========================================================
PROMPT [OPTIMIZADO] Iniciando procesamiento batch con BULK COLLECT y FORALL
PROMPT ========================================================

DECLARE
    v_start_time      TIMESTAMP;
    v_end_time        TIMESTAMP;
    c_batch_limit     CONSTANT PLS_INTEGER := 5000;
    v_total_processed NUMBER := 0;
    v_total_errors    NUMBER := 0;
    
    -- Variables para extraer contexto de errores por registro
    v_err_idx         PLS_INTEGER;
    v_err_code        NUMBER;
    v_err_tx_id       NUMBER;
    v_err_msg         VARCHAR2(4000);
    
    -- Definición de tipos de colección en memoria
    TYPE t_id_list IS TABLE OF ledger_transactions.transaction_id%TYPE;
    TYPE t_amt_list IS TABLE OF ledger_transactions.amount%TYPE;
    
    l_ids     t_id_list;
    l_amounts t_amt_list;
    
    CURSOR c_pending_tx IS
        SELECT transaction_id, amount
        FROM ledger_transactions
        WHERE status = 'PENDING'
          AND ROWNUM <= 100000;
          
    -- Excepción estándar para captura de fallos con SAVE EXCEPTIONS
    dml_errors EXCEPTION;
    PRAGMA EXCEPTION_INIT(dml_errors, -24381);
BEGIN
    v_start_time := SYSTIMESTAMP;
    
    OPEN c_pending_tx;
    LOOP
        FETCH c_pending_tx BULK COLLECT INTO l_ids, l_amounts LIMIT c_batch_limit;
        EXIT WHEN l_ids.COUNT = 0;
        
        BEGIN
            -- Ejecución vectorizada: 1 context switch por cada 5,000 filas
            FORALL i IN 1..l_ids.COUNT SAVE EXCEPTIONS
                UPDATE ledger_transactions
                SET status = 'COMPLETED',
                    payload_metadata = '{"batch": "reconciled_v2", "strategy": "bulk_forall"}'
                WHERE transaction_id = l_ids(i)
                  AND l_amounts(i) >= 0;
                  
            v_total_processed := v_total_processed + SQL%ROWCOUNT;
            
        EXCEPTION
            WHEN dml_errors THEN
                FOR err_idx IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
                    v_total_errors := v_total_errors + 1;
                    v_err_idx      := SQL%BULK_EXCEPTIONS(err_idx).ERROR_INDEX;
                    v_err_code     := SQL%BULK_EXCEPTIONS(err_idx).ERROR_CODE;
                    v_err_tx_id    := l_ids(v_err_idx);
                    v_err_msg      := 'Fallo de validacion en lote: ' || SQLERRM(-v_err_code);
                    
                    INSERT INTO batch_error_log (transaction_id, error_code, error_message)
                    VALUES (v_err_tx_id, v_err_code, v_err_msg);
                END LOOP;
        END;
        
        COMMIT;
    END LOOP;
    CLOSE c_pending_tx;
    
    v_end_time := SYSTIMESTAMP;
    
    DBMS_OUTPUT.PUT_LINE('--- Resumen Optimizado ---');
    DBMS_OUTPUT.PUT_LINE('Procesados exitosamente : ' || v_total_processed);
    DBMS_OUTPUT.PUT_LINE('Errores capturados      : ' || v_total_errors);
    DBMS_OUTPUT.PUT_LINE('Tiempo Total de CPU     : ' || 
        EXTRACT(SECOND FROM (v_end_time - v_start_time)) || ' segundos');
END;
/

EXIT;
