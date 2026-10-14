-- docker/init/02_seed_generator.sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = BENCHMARK_USER;

SET SERVEROUTPUT ON;
SET TIMING ON;

DECLARE
    v_start_time TIMESTAMP;
    v_end_time   TIMESTAMP;
    v_total_accounts NUMBER := 100000;  -- 100k cuentas maestras
    v_batch_size     NUMBER := 1000000; -- Lotes de 1M para balancear memoria y velocidad
    v_batches        NUMBER := 10;      -- 10 lotes = 10,000,000 transacciones
BEGIN
    v_start_time := SYSTIMESTAMP;
    DBMS_OUTPUT.PUT_LINE('--- Iniciando Carga Sintética de Datos ---');

    -- 1. Poblar 100,000 cuentas
    DBMS_OUTPUT.PUT_LINE('Poblando tabla ACCOUNTS (100k registros)...');
    INSERT /*+ APPEND */ INTO accounts (account_number, account_type, current_balance, created_at)
    SELECT 
        'ACC-' || LPAD(LEVEL, 10, '0'),
        CASE MOD(LEVEL, 3) 
            WHEN 0 THEN 'CHECKING' 
            WHEN 1 THEN 'SAVINGS' 
            ELSE 'CREDIT' 
        END,
        ROUND(DBMS_RANDOM.VALUE(100, 50000), 2),
        SYSTIMESTAMP - NUMTODSINTERVAL(DBMS_RANDOM.VALUE(30, 730), 'DAY')
    FROM dual
    CONNECT BY LEVEL <= v_total_accounts;
    COMMIT;

    -- 2. Configurar NOLOGGING en la tabla de transacciones para máxima velocidad
    EXECUTE IMMEDIATE 'ALTER TABLE ledger_transactions NOLOGGING';

    -- 3. Generar 10 Millones de Transacciones en lotes de 1M
    DBMS_OUTPUT.PUT_LINE('Poblando tabla LEDGER_TRANSACTIONS (10M registros sesgados)...');
    FOR b IN 1..v_batches LOOP
        INSERT /*+ APPEND */ INTO ledger_transactions (
            account_id,
            transaction_date,
            transaction_type,
            amount,
            status,
            payload_metadata,
            created_at
        )
        SELECT 
            -- Distribución Pareto: La potencia sesga los valores hacia números bajos de cuentas
            1 + TRUNC(v_total_accounts * POWER(DBMS_RANDOM.VALUE(0, 1), 3)),
            
            -- Rango temporal: últimos 730 días (2 años) con mayor probabilidad en fin de mes
            TRUNC(SYSDATE - DBMS_RANDOM.VALUE(0, 730)) + NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86399), 'SECOND'),
            
            -- Tipo de transacción
            CASE TRUNC(DBMS_RANDOM.VALUE(0, 4))
                WHEN 0 THEN 'DEBIT'
                WHEN 1 THEN 'CREDIT'
                WHEN 2 THEN 'TRANSFER_IN'
                ELSE 'TRANSFER_OUT'
            END,
            
            -- Monto transaccional
            ROUND(DBMS_RANDOM.VALUE(5, 7500), 2),
            
            -- Estado con sesgo pronunciado (Skew)
            CASE 
                WHEN DBMS_RANDOM.VALUE(0, 1) < 0.90 THEN 'COMPLETED'
                WHEN DBMS_RANDOM.VALUE(0, 1) < 0.97 THEN 'PENDING'
                WHEN DBMS_RANDOM.VALUE(0, 1) < 0.99 THEN 'FAILED'
                ELSE 'FLAGGED_FRAUD'
            END,
            
            '{"channel": "MOBILE_APP", "device_trust": "VERIFIED"}',
            SYSTIMESTAMP
        FROM dual
        CONNECT BY LEVEL <= v_batch_size;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Lote ' || b || ' / ' || v_batches || ' insertado exitosamente.');
    END LOOP;

    -- 4. Restaurar LOGGING y recopilar estadísticas para el Cost-Based Optimizer (CBO)
    EXECUTE IMMEDIATE 'ALTER TABLE ledger_transactions LOGGING';
    
    DBMS_OUTPUT.PUT_LINE('Recopilando estadísticas en CBO con DBMS_STATS...');
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname          => 'BENCHMARK_USER',
        tabname          => 'ACCOUNTS',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        cascade          => TRUE
    );

    DBMS_STATS.GATHER_TABLE_STATS(
        ownname          => 'BENCHMARK_USER',
        tabname          => 'LEDGER_TRANSACTIONS',
        estimate_percent => 10, -- Muestreo del 10% suficiente y rápido para 10M de filas
        cascade          => TRUE,
        method_opt       => 'FOR ALL COLUMNS SIZE AUTO'
    );

    v_end_time := SYSTIMESTAMP;
    DBMS_OUTPUT.PUT_LINE('--- Proceso completado exitosamente ---');
    DBMS_OUTPUT.PUT_LINE('Tiempo total: ' || EXTRACT(SECOND FROM (v_end_time - v_start_time)) || ' segundos');
END;
/