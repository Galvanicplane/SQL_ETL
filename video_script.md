# 10 Dakikalık Video Sunum Senaryosu (Gerçek FIFA 21 Veri Kümesi ETL)

Bu rehber, gerçek FIFA 21 veri kümesi üzerinde kurguladığınız ETL ve Veri Temizleme projesinin sunum videosunu çekmek için hazırlanmıştır. Senaryo, konuşma hızınıza göre yaklaşık **10 dakika** sürecek şekilde detaylandırılmıştır.

---

## ⏱️ ZAMAN PLANI VE AKIŞ ÖZETİ
1. **0:00 - 1:30 (Giriş & Senaryo):** Projenin konusu, gerçek FIFA 21 veri kümesinin tanıtımı, veri kalitesi sorunları ve indirme URL'si.
2. **1:30 - 3:00 (Ham Veri Aşaması - Staging):** Staging tablosunun ve ham CSV verisinin yapısı.
3. **3:00 - 4:30 (Hedef Veri Modeli - Production):** Normalize edilmiş yıldız/kar tanesi şeması (Clubs, Nationalities, Players) ve log tabloları.
4. **4:30 - 7:30 (ETL & Temizleme Mantığı):** Boyut dönüşümleri, maaş/değer temizleme, boy/kilo standardizasyonu ve kontrat yılı ayrıştırma algoritmaları.
5. **7:30 - 9:15 (Canlı Uygulama & Kalite Raporları):** pgAdmin üzerinde canlı çalıştırma, Before/After karşılaştırmaları (Messi & Ronaldo) ve veri analitiği sorguları.
6. **9:15 - 10:00 (Kapanış):** ETL sürecinin projeye kattığı değer ve özet.

---

## 🎬 SAHNE SAHNE DETAYLI AKIŞ VE KONUŞMA METNİ

### 1. Bölüm: Giriş ve Proje Amacı (0:00 - 1:30)
* **[AÇILACAK EKRAN]**: Tarayıcıda Kaggle/GitHub veya `download_data.py` dosyası.
* **[YAPILACAK EYLEM]**: Klasördeki dosyaları gösterin ve veri setinin indirme bağlantısını açıklayarak sunuma başlayın.
* **[KONUŞMA METNİ]**:
  > *"Merhaba hocam, bugün BLM4522 dersi proje ödevi kapsamında hazırladığım 'Gerçek Veri Kümeleri ile Veri Temizleme ve ETL Süreçleri Tasarımı' sunumunu gerçekleştireceğim.*
  >
  > *Projemi yapay veya küçük test verileri yerine, internetteki en popüler ve en kirli gerçek veri setlerinden biri olan **FIFA 21 Oyuncu Veri Seti** üzerinde gerçekleştirdim. Bu veri setini GitHub üzerindeki şu açık kaynaklı adresten çektim:* `https://raw.githubusercontent.com/krishan0520/Data_cleaning/master/fifa21_raw_data.csv`*.*
  >
  > *Bu veri seti yaklaşık 19.000 oyuncu kaydı ve 77 kolondan oluşuyor. İçerisinde veri mühendisliğinde sıkça karşılaşılan; yeni satır (\n) karakterleri barındıran metinler, Euro sembolü (€) ile K ve M gibi harfler içeren finansal değerler, hem santimetre hem feet/inç cinsinden boylar, hem libre (lbs) hem kilogram cinsinden kilolar gibi çok ciddi format uyuşmazlıkları ve kirli veriler var. Bugün bu verileri saf SQL ve PL/pgSQL kullanarak nasıl temizleyip normalize ettiğimizi göstereceğim."*

---

### 2. Bölüm: Ham Veri (Staging) Tablosu (1:30 - 3:00)
* **[AÇILACAK DOSYA]**: [01_staging_setup.sql](file:///c:/Users/erena/OneDrive/Masaüstü/Üni/BLM4522/5/01_staging_setup.sql)
* **[YAPILACAK EYLEM]**: `CREATE TABLE staging_fifa21` komutunu gösterin. 77 kolonun tamamının VARCHAR (TEXT) olarak tanımlandığını vurgulayın.
* **[KONUŞMA METNİ]**:
  > *"ETL'in ilk aşaması olan 'Extract' (Veri Çekme) adımı için veritabanında* `staging_fifa21` *adında bir geçici staging tablosu oluşturdum. Bu tablodaki tüm kolonları TEXT (yani VARCHAR) olarak tanımladım. Neden? Çünkü ham verideki hatalar ve uyuşmazlıklar sebebiyle veriyi doğrudan sayısal veya tarih tipindeki kolonlara eklemeye çalışırsak veritabanı hata verecektir. Dolayısıyla veriyi olduğu gibi, sıfır kısıtlamayla alıyoruz.*
  >
  > *Yazmış olduğum* `download_data.py` *ve* `build_sql.py` *scriptleri yardımıyla 8.26 MB boyutundaki CSV verisini çekip toplu ekleme (bulk insert) yöntemiyle bu staging tablosuna aktardım. Toplamda 18.979 satır ham veri ekranda gördüğünüz SQL dosyası üzerinden hızlıca sisteme yükleniyor."*

---

### 3. Bölüm: Üretim Şeması Tasarımı (3:00 - 4:30)
* **[AÇILACAK DOSYA]**: [02_production_setup.sql](file:///c:/Users/erena/OneDrive/Masaüstü/Üni/BLM4522/5/02_production_setup.sql)
* **[YAPILACAK EYLEM]**: `dim_nationalities`, `dim_clubs` ve `dim_players` tablolarının şemalarını gösterin. İlişkileri (Foreign Key) ve Log tablolarını açıklayın.
* **[KONUŞMA METNİ]**:
  > *"Veriler temizlendikten sonra onları normalize edilmiş bir üretim (Production) şemasına aktarıyoruz. Burada 3 boyutlu bir veri modeli kurdum:*
  > * `dim_nationalities` *tablosu, oyuncuların uyruklarını benzersiz olarak tutuyor.*
  > * `dim_clubs` *tablosu, kulüp isimlerini normalize ediyor.*
  > * `dim_players` *tablosu ise temizlenen tüm oyuncu verilerini tutuyor. Bu tabloda artık* `joined_date` *gerçek bir DATE,* `height_cm` *ve* `weight_kg` *ise sayısal veri tiplerindedir.* `value_eur` *ve* `wage_eur` *gibi finansal değerler ise aritmetik işlemlere uygun DECIMAL formatındadır.*
  >
  > *Ayrıca, ETL'in izlenebilirliği için* `etl_log` *ve veri kalitesi kurallarımıza uymadığı için elenen kayıtları nedenleriyle kaydeden* `rejected_records` *tablolarını kurguladım."*

---

### 4. Bölüm: ETL Süreci ve Dönüşüm Mantığı (4:30 - 7:30)
* **[AÇILACAK DOSYA]**: [03_etl_transformation.sql](file:///c:/Users/erena/OneDrive/Masaüstü/Üni/BLM4522/5/03_etl_transformation.sql)
* **[YAPILACAK EYLEM]**: Kodun içindeki regex ve veri dönüşüm formüllerini işaret edin. Özellikle Height, Weight ve Team_Contract kısımlarını gösterin.
* **[KONUŞMA METNİ]**:
  > *"ETL sürecinin beyni* `sp_run_etl()` *isimli saklı yordamdır. Burada PostgreSQL motorunun gücünden yararlanarak toplu (bulk) veri dönüşümleri gerçekleştirdim. En zorlayıcı temizleme kurallarını şu şekilde çözdüm:*
  >
  > * **1. Boy (Height) Standardizasyonu:** *Ham veride boylar hem '188cm' hem de '5'7"' (feet/inç) cinsinden girilmişti. SQL üzerinde bir CASE WHEN yapısı kurarak, eğer veri 'cm' içeriyorsa doğrudan sayıya dönüştürdüm. Eğer inç içeriyorsa feet kısmını 30.48 ile, inç kısmını 2.54 ile çarparak santimetreye çevirdim.*
  > * **2. Kilo (Weight) Standardizasyonu:** *Benzer şekilde, '72kg' olan kayıtları direkt aldım. '159lbs' olanları ise 0.453 ile çarparak kilograma normalize ettim.*
  > * **3. Kulüp ve Kontrat Ayrıştırması:** *En kirli alanlardan biri 'Team & Contract' kolonu idi. Hücrelerin içinde yeni satır (\n) karakterleri ile kulüp adı ve kontrat yılları (örn: '2004 ~ 2021') bir arada duruyordu. Öncelikle tüm yeni satır karakterlerini tekil hale getirdim.* `split_part` *ile ilk satırdan Kulüp Adını, ikinci satırdan kontrat süresini aldım. Kontrat süresini de '~' işaretine göre bölerek kontrat başlangıç ve bitiş yıllarını ayrı kolonlara çektim. Kontratı olmayanları 'Free Agent' olarak eşleştirdim.*
  > * **4. Finansal Değerler (Maaş ve Değer):** *Euro sembolünü attıktan sonra sonu 'M' ile biten piyasa değerlerini 1 milyon ile, 'K' ile biten haftalık maaşları ise 1000 ile çarparak gerçek sayısal Euro değerlerine ulaştım.*
  >
  > *Son aşamada, bu verileri boyut tablolarındaki ID'lerle eşleştirerek* `dim_players` *tablosuna* `ON CONFLICT` *(Upsert) mantığıyla yükledim."*

---

### 5. Bölüm: Canlı Demo ve Veri Kalitesi Raporları (7:30 - 9:15)
* **[AÇILACAK EKRAN]**: pgAdmin sorgu arayüzü ve [04_data_quality_reports.sql](file:///c:/Users/erena/OneDrive/Masaüstü/Üni/BLM4522/5/04_data_quality_reports.sql) dosyası.
* **[YAPILACAK EYLEM]**: Sırasıyla sorguları çalıştırın ve sonuçları gösterin:
  1. `CALL sp_run_etl();` komutunu çalıştırın.
  2. `vw_etl_summary` ve `vw_data_quality_metrics` görünümlerini sorgulayın.
  3. Lionel Messi (ID: 158023) Before/After karşılaştırma sorgusunu çalıştırıp ekrandaki farkı vurgulayın.
  4. `vw_club_stats` sorgusunu çalıştırıp kulüplerin temizlenmiş veriler üzerindeki analizini gösterin.
* **[KONUŞMA METNİ]**:
  > *"Şimdi bu süreci canlı olarak çalıştıralım. pgAdmin üzerinde* `CALL sp_run_etl();` *komutunu tetikliyorum. Gördüğünüz gibi 19.000 satırlık karmaşık veri dönüşümü yaklaşık 1 saniye içerisinde başarıyla tamamlandı.*
  >
  > *Şimdi* `vw_etl_summary` *ve* `vw_data_quality_metrics` *görünümlerine bakalım. Toplamda 18.979 satır verinin başarıyla işlendiğini görebilirsiniz.*
  >
  > *Şimdi Lionel Messi kaydı üzerinden Before/After yani temizlik öncesi ve sonrası durumunu karşılaştıralım. Ekranda gördüğünüz gibi ham veride Messi'nin boyu* `5'7"`*, kilosu ise* `159lbs` *olarak inç/libre sisteminde görünüyordu. ETL sonrasında ise bu değerler otomatik olarak* `170 cm` *ve* `72 kg` *olarak standartlaştırılmış.*
  >
  > *Aynı şekilde Messi'nin piyasa değeri ham veride* `€67.5M` *ve maaşı* `€560K` *metni iken, üretim tablomuzda* `67.500.000` *ve* `560.000` *olarak temizlenmiş. Kontratı ise başarıyla 'FC Barcelona' kulübü altında başlangıç yılı 2004 ve bitiş yılı 2021 olarak ayrı kolonlara bölünmüş.*
  >
  > *Son olarak temiz veri üzerinden analizler yapabiliriz.* `vw_club_stats` *görünümünü sorguladığımda, hangi kulübün oyuncularının yaş ortalamasını, genel ratingini, toplam piyasa değerini ve haftalık maaş ortalamalarını kuruşu kuruşuna görebiliyoruz. Temiz veri sayesinde işletmeler artık doğru kararlar verebilir."*

---

### 6. Bölüm: Kapanış (9:15 - 10:00)
* **[KONUŞMA METNİ]**:
  > *"Özetlemek gerekirse; bu projeyle büyük ölçekli ve son derece kirli, gerçek bir veri kümesini alıp veri ambarı modeline uygun şekilde temizleyen ve yapılandıran bir SQL ETL hattı tasarlamış olduk.*
  >
  > *Veri entegrasyonu ve temizlemenin, veri analitiği projelerinde ne kadar kritik bir rol oynadığını bu gerçek örnekle görmüş olduk. Dinlediğiniz için teşekkür ederim."*

---
## 💡 VİDEO İPUÇLARI
1. **Dosyaları Hazır Tutun:** Videoya başlamadan önce `download_data.py` ve `build_sql.py` scriptlerini çalıştırıp veritabanını hazırlayın. Video sırasında sadece `CALL sp_run_etl();` komutunu ve sonrasındaki analiz sorgularını pgAdmin üzerinde canlı çalıştırın.
2. **Yazı Boyutu:** pgAdmin sorgu panelinde `Ctrl` + `+` tuşlarına basarak metin boyutunu büyütün ki izleyici kodları ve tabloları net görsün.
