SET SERVEROUTPUT ON;
SET TIMING ON;
SET ECHO OFF;
SET FEEDBACK OFF;

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = BENCHMARK_USER;

PROMPT ========================================================
PROMPT [BASELINE] Iniciando procesamiento fila a fila (100k registros)
PROMPT ========================================================

DECLARE
    v_start_time   TIMESTAMP;
    v_end_time     TIMESTAMP;
    v_processed    NUMBER := 0;
    v_errors       NUMBER := 0;
    
    -- Variables para almacenar contexto de error
    v_err_code     NUMBER;
    v_err_msg      VARCHAR2(4000);
    
    CURSOR c_pending_tx IS
        SELECT transaction_id, amount
        FROM ledger_transactions
        WHERE status = 'PENDING'
          AND ROWNUM <= 100000;
          
    r_tx c_pending_tx%ROWTYPE;
BEGIN
    v_start_time := SYSTIMESTAMP;
    
    OPEN c_pending_tx;
    LOOP
        FETCH c_pending_tx INTO r_tx;
        EXIT WHEN c_pending_tx%NOTFOUND;
        
        BEGIN
            -- Regla de negocio simulada
            IF r_tx.amount < 0 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Monto transaccional invalido.');
            END IF;
            
            -- Actualización fila a fila (Context switch PL/SQL -> SQL en cada fila)
            UPDATE ledger_transactions
            SET status = 'COMPLETED',
                payload_metadata = '{"batch": "reconciled_v1", "strategy": "slow_by_slow"}'
            WHERE transaction_id = r_tx.transaction_id;
            
            v_processed := v_processed + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_errors := v_errors + 1;
                v_err_code := SQLCODE;
                v_err_msg  := SUBSTR(SQLERRM, 1, 4000);
                
                INSERT INTO batch_error_log (transaction_id, error_code, error_message)
                VALUES (r_tx.transaction_id, v_err_code, v_err_msg);
        END;
    END LOOP;
    CLOSE c_pending_tx;
    
    COMMIT;
    v_end_time := SYSTIMESTAMP;
    
    DBMS_OUTPUT.PUT_LINE('--- Resumen Baseline ---');
    DBMS_OUTPUT.PUT_LINE('Procesados exitosamente : ' || v_processed);
    DBMS_OUTPUT.PUT_LINE('Errores capturados      : ' || v_errors);
    DBMS_OUTPUT.PUT_LINE('Tiempo Total de CPU     : ' || 
        EXTRACT(SECOND FROM (v_end_time - v_start_time)) || ' segundos');
END;
/

EXIT;
