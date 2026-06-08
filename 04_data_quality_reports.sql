-- ============================================================================
-- 04_data_quality_reports.sql
-- ----------------------------------------------------------------------------
-- Amaç: FIFA 21 ETL süreci sonrasında veri kalitesini raporlayan ve temizlenen
--       veriler üzerinden analiz yapan Görünümlerin (Views) oluşturulması.
-- ============================================================================

-- Var olan görünümleri temizle
DROP VIEW IF EXISTS vw_club_stats CASCADE;
DROP VIEW IF EXISTS vw_nationality_stats CASCADE;
DROP VIEW IF EXISTS vw_data_quality_metrics CASCADE;
DROP VIEW IF EXISTS vw_etl_summary CASCADE;

-- 1. ETL Genel Çalışma Özeti Görünümü
CREATE VIEW vw_etl_summary AS
SELECT 
    run_id,
    run_timestamp,
    status,
    extracted_records AS ham_kayit_sayisi,
    loaded_records AS yuklenen_temiz_sayi,
    rejected_records AS reddedilen_sayi,
    ROUND((loaded_records::DECIMAL / NULLIF(extracted_records, 0)) * 100, 2) AS basari_yuzdesi,
    error_message
FROM etl_log;

-- 2. Veri Kalitesi Metrikleri Görünümü
CREATE VIEW vw_data_quality_metrics AS
SELECT 
    (SELECT COUNT(*) FROM staging_fifa21) AS ham_toplam_satir,
    (SELECT COUNT(*) FROM dim_players) AS temiz_toplam_oyuncu,
    (SELECT COUNT(*) FROM rejected_records) AS toplam_reddedilen,
    ROUND(((SELECT COUNT(*) FROM rejected_records)::DECIMAL / (SELECT COUNT(*) FROM staging_fifa21)) * 100, 2) AS hata_orani_yuzde;

-- 3. Kulüp Bazlı Temizlenmiş Veri Analizi Görünümü
CREATE VIEW vw_club_stats AS
SELECT 
    c.club_name AS kulup_adi,
    COUNT(p.player_id) AS oyuncu_sayisi,
    ROUND(AVG(p.age), 1) AS ortalama_yas,
    ROUND(AVG(p.overall_rating), 1) AS ortalama_rating,
    ROUND(AVG(p.value_eur) / 1000000, 2) AS ortalama_deger_m_eur,
    ROUND(AVG(p.wage_eur) / 1000, 2) AS ortalama_haftalik_maas_k_eur
FROM dim_players p
JOIN dim_clubs c ON p.club_id = c.club_id
GROUP BY c.club_name
HAVING COUNT(p.player_id) > 10;

-- 4. Uyruk Bazlı Ortalama Oyuncu Gücü ve Değer Analizi Görünümü
CREATE VIEW vw_nationality_stats AS
SELECT 
    n.nationality_name AS uyruk,
    COUNT(p.player_id) AS oyuncu_sayisi,
    ROUND(AVG(p.overall_rating), 1) AS ortalama_rating,
    ROUND(SUM(p.value_eur) / 1000000, 2) AS toplam_deger_m_eur
FROM dim_players p
JOIN dim_nationalities n ON p.nationality_id = n.nationality_id
GROUP BY n.nationality_name
ORDER BY oyuncu_sayisi DESC;


-- ============================================================================
-- ANALİZ VE DEMO SORGU REÇETELERİ (Sunum videosunda gösterilecek sorgular)
-- ============================================================================

/*
-- DEMO 1: ETL'i Tetikleme Komutu
CALL sp_run_etl();

-- DEMO 2: ETL Çalışma Özeti Kontrolü
SELECT * FROM vw_etl_summary;

-- DEMO 3: Genel Kalite Metrikleri
SELECT * FROM vw_data_quality_metrics;

-- DEMO 4: En Değerli Kulüpler (Veri temizleme sonrası elde edilen temiz veri analizi)
SELECT * FROM vw_club_stats ORDER BY ortalama_deger_m_eur DESC LIMIT 10;

-- DEMO 5: Ülke Analizi
SELECT * FROM vw_nationality_stats LIMIT 10;

-- DEMO 6: Dönüşüm Karşılaştırmaları (Before / After Örnekleri)

-- A) Boy ve Kilo Dönüşüm Kontrolü (Örn: Lionel Messi)
SELECT 
    'HAM VERİ (Staging)' AS durum, 
    Height AS boy_ham, 
    Weight AS kilo_ham 
FROM staging_fifa21 
WHERE ID = '158023'
UNION ALL
SELECT 
    'TEMİZ VERİ (Production)' AS durum, 
    height_cm::text || ' cm' AS boy_temiz, 
    weight_kg::text || ' kg' AS kilo_temiz 
FROM dim_players 
WHERE player_id = 158023;

-- B) Piyasa Değeri, Maaş ve Kontrat Dönüşüm Kontrolü (Örn: C. Ronaldo ve L. Messi)
-- Ham Veri:
SELECT 
    Name, 
    Value AS deger_ham, 
    Wage AS maas_ham, 
    Team_Contract AS kontrat_ham 
FROM staging_fifa21 
WHERE ID IN ('158023', '20801');

-- Temiz Veri:
SELECT 
    p.short_name, 
    p.value_eur AS deger_temiz_eur, 
    p.wage_eur AS maas_temiz_eur, 
    c.club_name AS kulup, 
    p.contract_start AS kontrat_baslangic, 
    p.contract_end AS kontrat_bitis, 
    p.contract_status AS kontrat_durumu
FROM dim_players p
JOIN dim_clubs c ON p.club_id = c.club_id
WHERE p.player_id IN (158023, 20801);
*/
