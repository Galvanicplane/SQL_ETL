-- ============================================================================
-- 03_etl_transformation.sql
-- ----------------------------------------------------------------------------
-- Amaç: FIFA 21 ham verilerini temizleyen, dönüştüren, normalize eden ve 
--       hedef üretim tablolarına yükleyen ETL saklı yordamının yazılması.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_run_etl()
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id INT;
    v_extracted INT := 0;
    v_loaded INT := 0;
    v_rejected INT := 0;
    v_error_msg TEXT;
BEGIN
    -- 1. ETL Çalışma Logunu Başlat
    INSERT INTO etl_log (status, error_message)
    VALUES ('RUNNING', 'FIFA 21 ETL süreci başladı.')
    RETURNING run_id INTO v_run_id;

    -- Ham veri adedini say (Extract Aşaması)
    SELECT COUNT(*) INTO v_extracted FROM staging_fifa21;

    -- ========================================================================
    -- ADIM 1: KALİTE KONTROLLERİ VE REDDETME (DATA REJECTIONS)
    -- ========================================================================
    -- Oyuncu ID'si veya İsmi eksik ya da geçersiz olan kayıtları reddet.
    INSERT INTO rejected_records (run_id, raw_record_id, raw_name, rejection_reason)
    SELECT 
        v_run_id,
        ID,
        LongName,
        CASE 
            WHEN ID IS NULL OR TRIM(ID) = '' THEN 'Oyuncu ID bilgisi eksik (NULL)'
            WHEN NOT (ID ~ '^\d+$') THEN 'Geçersiz Oyuncu ID formatı (Sayısal değil)'
            WHEN LongName IS NULL OR TRIM(LongName) = '' THEN 'Oyuncu ismi eksik (NULL)'
            ELSE 'Bilinmeyen Hata'
        END
    FROM staging_fifa21
    WHERE 
        ID IS NULL OR TRIM(ID) = ''
        OR NOT (ID ~ '^\d+$')
        OR LongName IS NULL OR TRIM(LongName) = '';

    -- ========================================================================
    -- ADIM 2: VERİ TEMİZLEME VE DÖNÜŞTÜRME (TRANSFORM & LOAD)
    -- ========================================================================
    -- Performans açısından, temizlenmiş verileri geçici (temporary) bir tabloya
    -- alıp oradan boyut tablolarını besleyeceğiz.

    DROP TABLE IF EXISTS temp_cleaned_players;
    CREATE TEMP TABLE temp_cleaned_players (
        player_id INT,
        long_name VARCHAR(255),
        short_name VARCHAR(100),
        age INT,
        overall_rating INT,
        potential_rating INT,
        nationality VARCHAR(100),
        club_name VARCHAR(255),
        contract_start INT,
        contract_end INT,
        contract_status VARCHAR(50),
        joined_date DATE,
        height_cm INT,
        weight_kg INT,
        value_eur DECIMAL(15,2),
        wage_eur DECIMAL(15,2),
        release_clause_eur DECIMAL(15,2),
        preferred_foot VARCHAR(10),
        best_position VARCHAR(10),
        hits INT
    );

    -- Ham verileri temizleyip geçici tabloya aktar
    INSERT INTO temp_cleaned_players
    WITH cleaned_raw AS (
        SELECT 
            CAST(ID AS INT) AS player_id,
            TRIM(LongName) AS long_name,
            TRIM(Name) AS short_name,
            CAST(Age AS INT) AS age,
            CAST(OVA AS INT) AS overall_rating,
            CAST(POT AS INT) AS potential_rating,
            TRIM(Nationality) AS nationality,
            
            -- Team & Contract kolonu içindeki yeni satırları temizle
            -- chr(10) PostgreSQL'de line feed (\n) karakteridir
            TRIM(split_part(regexp_replace(trim(both E'\r\n\t ' from Team_Contract), '[\r\n\t]+', chr(10), 'g'), chr(10), 1)) AS club_raw,
            regexp_replace(trim(both E'\r\n\t ' from Team_Contract), '[\r\n\t]+', chr(10), 'g') AS tc_clean,
            
            -- Boy (Height) Standardizasyonu (Örn: 5'7" -> cm veya 188cm -> cm)
            CASE 
                WHEN Height LIKE '%cm' THEN CAST(REPLACE(Height, 'cm', '') AS INT)
                WHEN Height LIKE '%''%"' THEN 
                    ROUND(
                        (CAST(SPLIT_PART(Height, '''', 1) AS DECIMAL) * 30.48) + 
                        (CAST(REPLACE(SPLIT_PART(Height, '''', 2), '"', '') AS DECIMAL) * 2.54)
                    )::INT
                ELSE NULL 
            END AS height_cm,
            
            -- Kilo (Weight) Standardizasyonu (Örn: 159lbs -> kg veya 72kg -> kg)
            CASE 
                WHEN Weight LIKE '%kg' THEN CAST(REPLACE(Weight, 'kg', '') AS INT)
                WHEN Weight LIKE '%lbs' THEN 
                    ROUND(CAST(REPLACE(Weight, 'lbs', '') AS DECIMAL) * 0.453592)::INT
                ELSE NULL 
            END AS weight_kg,
            
            -- Tarih (Joined) Standardizasyonu
            CASE 
                WHEN Joined IS NULL OR Joined = 'NULL' THEN NULL
                ELSE to_date(Joined, 'Mon DD, YYYY')
            END AS joined_date,
            
            -- Piyasa Değeri (Value) Standardizasyonu (Örn: €67.5M -> 67500000, €560K -> 560000)
            CASE 
                WHEN Value IS NULL OR Value = 'NULL' OR Value = '€0' THEN 0.0
                WHEN Value LIKE '€%M' THEN CAST(REPLACE(REPLACE(Value, '€', ''), 'M', '') AS DECIMAL) * 1000000
                WHEN Value LIKE '€%K' THEN CAST(REPLACE(REPLACE(Value, '€', ''), 'K', '') AS DECIMAL) * 1000
                ELSE CAST(REPLACE(Value, '€', '') AS DECIMAL)
            END AS value_eur,
            
            -- Maaş (Wage) Standardizasyonu
            CASE 
                WHEN Wage IS NULL OR Wage = 'NULL' OR Wage = '€0' THEN 0.0
                WHEN Wage LIKE '€%M' THEN CAST(REPLACE(REPLACE(Wage, '€', ''), 'M', '') AS DECIMAL) * 1000000
                WHEN Wage LIKE '€%K' THEN CAST(REPLACE(REPLACE(Wage, '€', ''), 'K', '') AS DECIMAL) * 1000
                ELSE CAST(REPLACE(Wage, '€', '') AS DECIMAL)
            END AS wage_eur,
            
            -- Serbest Kalma Bedeli (Release Clause) Standardizasyonu
            CASE 
                WHEN Release_Clause IS NULL OR Release_Clause = 'NULL' OR Release_Clause = '€0' THEN 0.0
                WHEN Release_Clause LIKE '€%M' THEN CAST(REPLACE(REPLACE(Release_Clause, '€', ''), 'M', '') AS DECIMAL) * 1000000
                WHEN Release_Clause LIKE '€%K' THEN CAST(REPLACE(REPLACE(Release_Clause, '€', ''), 'K', '') AS DECIMAL) * 1000
                ELSE CAST(REPLACE(Release_Clause, '€', '') AS DECIMAL)
            END AS release_clause_eur,
            
            TRIM(foot) AS preferred_foot,
            TRIM(BP) AS best_position,
            
            -- Tıklanma (Hits) sayısı (Örn: \n342 veya 1.6K)
            CASE 
                WHEN Hits IS NULL OR Hits = 'NULL' OR trim(regexp_replace(Hits, '[\r\n\t]+', '', 'g')) = '' THEN 0
                WHEN trim(regexp_replace(Hits, '[\r\n\t]+', '', 'g')) LIKE '%K' 
                    THEN (CAST(REPLACE(trim(regexp_replace(Hits, '[\r\n\t]+', '', 'g')), 'K', '') AS DECIMAL) * 1000)::INT
                ELSE CAST(trim(regexp_replace(Hits, '[\r\n\t]+', '', 'g')) AS INT)
            END AS hits
        FROM staging_fifa21
        WHERE ID IN (SELECT ID FROM staging_fifa21 EXCEPT SELECT raw_record_id FROM rejected_records WHERE run_id = v_run_id)
    )
    SELECT 
        player_id, long_name, short_name, age, overall_rating, potential_rating, nationality,
        -- Kulüp ve Kontrat Durumu Ayrıştırması
        CASE 
            WHEN tc_clean = 'Free' OR tc_clean IS NULL OR tc_clean = '' THEN 'Free Agent'
            ELSE club_raw
        END AS club_name,
        CASE 
            WHEN tc_clean = 'Free' OR tc_clean IS NULL OR tc_clean = '' THEN NULL
            WHEN tc_clean LIKE '%~%' THEN CAST(TRIM(SPLIT_PART(SPLIT_PART(tc_clean, chr(10), 2), '~', 1)) AS INT)
            ELSE NULL
        END AS contract_start,
        CASE 
            WHEN tc_clean = 'Free' OR tc_clean IS NULL OR tc_clean = '' THEN NULL
            WHEN tc_clean LIKE '%~%' THEN CAST(TRIM(SPLIT_PART(SPLIT_PART(tc_clean, chr(10), 2), '~', 2)) AS INT)
            ELSE NULL
        END AS contract_end,
        CASE 
            WHEN tc_clean = 'Free' OR tc_clean IS NULL OR tc_clean = '' THEN 'Free'
            WHEN tc_clean LIKE '%On Loan%' THEN 'On Loan'
            WHEN tc_clean LIKE '%~%' THEN 'Contracted'
            ELSE 'Unknown'
        END AS contract_status,
        joined_date, height_cm, weight_kg, value_eur, wage_eur, release_clause_eur, preferred_foot, best_position, hits
    FROM cleaned_raw;

    -- A) Yeni Uyrukları (Nationality) dim_nationalities Tablosuna Yükle
    INSERT INTO dim_nationalities (nationality_name)
    SELECT DISTINCT nationality 
    FROM temp_cleaned_players
    WHERE nationality IS NOT NULL
    ON CONFLICT (nationality_name) DO NOTHING;

    -- B) Yeni Kulüpleri (Club) dim_clubs Tablosuna Yükle
    INSERT INTO dim_clubs (club_name)
    SELECT DISTINCT club_name 
    FROM temp_cleaned_players
    WHERE club_name IS NOT NULL
    ON CONFLICT (club_name) DO NOTHING;

    -- C) Oyuncuları dim_players Tablosuna Yükle (UPSERT / ON CONFLICT)
    INSERT INTO dim_players (
        player_id, long_name, short_name, age, overall_rating, potential_rating,
        nationality_id, club_id, contract_start, contract_end, contract_status,
        joined_date, height_cm, weight_kg, value_eur, wage_eur, release_clause_eur,
        preferred_foot, best_position, hits, updated_at
    )
    SELECT 
        t.player_id, t.long_name, t.short_name, t.age, t.overall_rating, t.potential_rating,
        n.nationality_id, c.club_id, t.contract_start, t.contract_end, t.contract_status,
        t.joined_date, t.height_cm, t.weight_kg, t.value_eur, t.wage_eur, t.release_clause_eur,
        t.preferred_foot, t.best_position, t.hits, CURRENT_TIMESTAMP
    FROM temp_cleaned_players t
    LEFT JOIN dim_nationalities n ON t.nationality = n.nationality_name
    LEFT JOIN dim_clubs c ON t.club_name = c.club_name
    ON CONFLICT (player_id) DO UPDATE 
    SET 
        long_name = EXCLUDED.long_name,
        short_name = EXCLUDED.short_name,
        age = EXCLUDED.age,
        overall_rating = EXCLUDED.overall_rating,
        potential_rating = EXCLUDED.potential_rating,
        nationality_id = EXCLUDED.nationality_id,
        club_id = EXCLUDED.club_id,
        contract_start = EXCLUDED.contract_start,
        contract_end = EXCLUDED.contract_end,
        contract_status = EXCLUDED.contract_status,
        joined_date = EXCLUDED.joined_date,
        height_cm = EXCLUDED.height_cm,
        weight_kg = EXCLUDED.weight_kg,
        value_eur = EXCLUDED.value_eur,
        wage_eur = EXCLUDED.wage_eur,
        release_clause_eur = EXCLUDED.release_clause_eur,
        preferred_foot = EXCLUDED.preferred_foot,
        best_position = EXCLUDED.best_position,
        hits = EXCLUDED.hits,
        updated_at = CURRENT_TIMESTAMP;

    -- D) Log Tablosunu Güncelle ve Tamamla
    SELECT COUNT(*) INTO v_loaded FROM dim_players;
    SELECT COUNT(*) INTO v_rejected FROM rejected_records WHERE run_id = v_run_id;

    UPDATE etl_log 
    SET 
        status = 'SUCCESS',
        extracted_records = v_extracted,
        loaded_records = v_loaded,
        rejected_records = v_rejected,
        error_message = 'FIFA 21 ETL süreci başarıyla tamamlandı.'
    WHERE run_id = v_run_id;

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_msg = PG_EXCEPTION_CONTEXT;
        v_error_msg := SQLERRM || ' | CONTEXT: ' || v_error_msg;
        
        UPDATE etl_log 
        SET 
            status = 'FAILED',
            error_message = v_error_msg
        WHERE run_id = v_run_id;
        
        RAISE EXCEPTION 'ETL Sürecinde Kritik Hata: %', SQLERRM;
END;
$$;
