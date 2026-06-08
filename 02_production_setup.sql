-- ============================================================================
-- 02_production_setup.sql
-- ----------------------------------------------------------------------------
-- Amaç: Temizlenmiş, normalize edilmiş ve dönüştürülmüş FIFA 21 verilerinin 
--       tutulacağı Hedef (Production) tablolarının oluşturulması.
-- ============================================================================

-- Tabloları temizle (Yeniden çalıştırılabilirlik/Idempotency için - sıra önemlidir)
DROP TABLE IF EXISTS rejected_records CASCADE;
DROP TABLE IF EXISTS etl_log CASCADE;
DROP TABLE IF EXISTS dim_players CASCADE;
DROP TABLE IF EXISTS dim_clubs CASCADE;
DROP TABLE IF EXISTS dim_nationalities CASCADE;

-- 1. Uyruk Boyut Tablosu (dim_nationalities)
CREATE TABLE dim_nationalities (
    nationality_id SERIAL PRIMARY KEY,
    nationality_name VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Kulüp Boyut Tablosu (dim_clubs)
CREATE TABLE dim_clubs (
    club_id SERIAL PRIMARY KEY,
    club_name VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Oyuncu Boyut Tablosu (dim_players)
CREATE TABLE dim_players (
    player_id INT PRIMARY KEY,                    -- FIFA ID'si (Benzersiz iş anahtarı)
    long_name VARCHAR(255) NOT NULL,
    short_name VARCHAR(100) NOT NULL,
    age INT,
    overall_rating INT,                           -- OVA
    potential_rating INT,                         -- POT
    nationality_id INT REFERENCES dim_nationalities(nationality_id) ON DELETE SET NULL,
    club_id INT REFERENCES dim_clubs(club_id) ON DELETE SET NULL,
    contract_start INT,                           -- Eşleşen kontrat başlangıç yılı
    contract_end INT,                             -- Eşleşen kontrat bitiş yılı
    contract_status VARCHAR(50),                  -- 'Contracted', 'On Loan', 'Free'
    joined_date DATE,                             -- Joined kolonu DATE formatında
    height_cm INT,                                -- Yükseklik cm cinsinden
    weight_kg INT,                                -- Ağırlık kg cinsinden
    value_eur DECIMAL(15,2),                      -- Piyasa Değeri (Euro)
    wage_eur DECIMAL(15,2),                       -- Haftalık Maaş (Euro)
    release_clause_eur DECIMAL(15,2),             -- Serbest Kalma Bedeli (Euro)
    preferred_foot VARCHAR(10),                   -- Sol / Sağ
    best_position VARCHAR(10),                    -- En iyi oynadığı pozisyon
    hits INT,                                     -- Oyuncu profil tıklanma sayısı
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. ETL Çalışma Logları
CREATE TABLE etl_log (
    run_id SERIAL PRIMARY KEY,
    run_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL,                  -- 'SUCCESS', 'FAILED'
    extracted_records INT DEFAULT 0,
    loaded_records INT DEFAULT 0,
    rejected_records INT DEFAULT 0,
    error_message TEXT
);

-- 5. Reddedilen Kayıtlar Tablosu
CREATE TABLE rejected_records (
    reject_id SERIAL PRIMARY KEY,
    run_id INT,
    raw_record_id VARCHAR(50),                    -- Hatalı kaydın ham ID'si
    raw_name VARCHAR(255),
    rejection_reason VARCHAR(255) NOT NULL,
    rejected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dizin indeksleri (Arama ve Join hızını artırmak için)
CREATE INDEX idx_players_club ON dim_players(club_id);
CREATE INDEX idx_players_nationality ON dim_players(nationality_id);
CREATE INDEX idx_players_ova ON dim_players(overall_rating);

-- Tabloların boş şekilde oluşturulduğunu kontrol et
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('dim_nationalities', 'dim_clubs', 'dim_players', 'etl_log', 'rejected_records');
