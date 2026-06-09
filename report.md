# Veri Temizleme ve ETL Süreçleri Tasarımı Proje Raporu

## Özet

Bu çalışmada, büyük veri ambarı projelerinde veri kalitesini ve entegrasyonunu sağlamak amacıyla PostgreSQL veritabanı üzerinde uçtan uca bir ETL (Extract, Transform, Load) boru hattı tasarlanmış ve uygulanmıştır. Çalışma kapsamında, Kaggle ve GitHub üzerinde paylaşılan, yapısal bozukluklar, tutarsız formatlar ve mükerrer kayıtlar barındıran gerçek dünya veri seti "FIFA 21 Oyuncu Veri Kümesi" (18.979 satır, 77 öznitelik) ham kaynak olarak seçilmiştir. İlk aşamada verilerin kısıtlamasız geçici bir katmana (Staging) aktarımı sağlanmış; ikinci aşamada ise PL/pgSQL tabanlı saklı yordamlar kullanılarak gelişmiş regex, metin analitiği ve veri türü dönüşümleri aracılığıyla temizlik ve normalizasyon süreçleri işletilmiştir. Boyut modelleme mimarisine uygun olarak tasarlanan üretim şemasına temiz veriler aktarılırken, kalite kurallarına uymayan kayıtlar da izlenebilirlik amacıyla loglanmıştır. Sonuç aşamasında, veri kalitesi oranları ve analitik metrikleri raporlayan veritabanı görünümleri (Views) oluşturularak sistemin doğruluğu test edilmiştir.

---

## Giriş ve Projenin Amacı

Veri odaklı karar destek sistemlerinde ve veri ambarı yapılarında en kritik aşamalardan biri, sisteme beslenen verilerin güvenilirliğidir. Çoğu zaman farklı platformlardan, mobil uygulamalardan veya web servislerinden gelen veriler standart formatlara uymamakta, eksik ya da mükerrer kayıtlar içermekte ve bu durum "Çöp Girerse Çöp Çıkar" (Garbage In, Garbage Out) ilkesi gereği analiz sonuçlarını saptırmaktadır. 

Bu projenin amacı, büyük veri kümelerindeki bu tip veri kalitesi ve biçimsel tutarsızlık sorunlarını çözmek amacıyla ilişkisel veritabanı yönetim sistemlerinin sunduğu yerleşik veri işleme mekanizmalarını kullanarak performans odaklı, ölçeklenebilir ve işlem (transaction) güvenliğine sahip bir ETL mimarisi tasarlamaktır. Proje, harici programlama dillerine bağımlı kalmaksızın, veri dönüşümlerinin tamamen veritabanı motorunun kendi gücüyle yapılmasını hedeflemektedir.

---

## Kullanılan Veri Kümesi ve Veri Kalitesi Problemleri

Projede kullanılan ham veri kümesi, 18.979 satır ve 77 kolondan oluşan gerçek FIFA 21 veri setidir. Veri kümesi üzerinde yapılan keşifsel analizlerde tespit edilen ve ETL sürecinde çözülmesi hedeflenen temel veri kalitesi problemleri şunlardır:

* **Sayısal Olmayan Değerlerin Varlığı:** Oyuncuların haftalık maaşları (`Wage`), serbest kalma maddeleri (`Release Clause`) ve piyasa değerleri (`Value`) gibi finansal veriler, sayısal veri tipi yerine metin (VARCHAR) tipinde ve başında Euro simgesi (€), sonunda ise bin değerini temsil eden 'K' veya milyon değerini temsil eden 'M' ekleriyle tutulmaktadır.
* **Metrik Sistem Uyuşmazlığı:** Boy (`Height`) kolonu hem feet/inç formatında (Örn: `5'7"`) hem de santimetre formatında (Örn: `188cm`) girilmiştir. Ağırlık (`Weight`) kolonu ise hem libre (`159lbs`) hem de kilogram (`72kg`) cinsinden karmaşık değerler içermektedir.
* **Biçimsel Bozukluklar ve Yeni Satır Karakterleri:** Kulüp ve kontrat sürelerini içeren `Team_Contract` alanı, metin bloğu içinde çok sayıda yeni satır (`\n`) ve boşluk karakteri barındırmakta, kulüp adı ile kontrat yılları tek bir hücrede tutulmaktadır.
* **Mükerrer Kayıtlar:** Aynı oyuncu ID'sine sahip kayıtlar veri setinde birden fazla kez yer almaktadır. Bu durum veritabanında veri tekrarına ve tutarsızlıklara sebep olmaktadır.

---

## Veritabanı Şeması Tasarımı

Projede veri ambarı standartlarına uygun olarak iki katmanlı bir şema tasarımı kurgulanmıştır:

### Geçici Katman (Staging Schema)
`staging_fifa21` tablosu, kaynak verinin kısıtlamasız bir şekilde içeri aktarılabilmesi amacıyla tüm kolonları `TEXT` tipinde barındıracak şekilde tasarlanmıştır. Bu sayede ham veri seti üzerinde herhangi bir dönüşüm hatası yaşanmadan ilk veri yüklemesi (Extract) gerçekleştirilir.

### Üretim Katmanı (Production Schema)
Normalize edilmiş, veri tipleri optimize edilmiş ve kısıtlamaları (Foreign Key, Unique) tanımlanmış hedef katmandır. Şu tablolardan oluşmaktadır:
* **dim_nationalities:** Oyuncu uyruklarını benzersiz olarak saklayan boyut tablosu.
* **dim_clubs:** Kulüp isimlerini benzersiz şekilde normalize eden boyut tablosu.
* **dim_players:** Temizlenmiş boy, kilo, maaş, kontrat ve rating bilgilerini tutan, boyut tablolarıyla ilişkili ana tablo.
* **etl_log:** ETL sürecinin çalışma tarihini, durumunu, işlenen satır sayılarını ve hata mesajlarını kaydeden metadata tablosu.
* **rejected_records:** Kalite kontrolünden geçemeyen hatalı kayıtların neden reddedildiğini gösteren hata kayıt tablosu.

---

## ETL ve Veri Temizleme Sürecinin Gerçekleştirilmesi

ETL süreci, ilişkisel bütünlüğü korumak ve hata durumunda veritabanını tutarlı bir duruma geri döndürmek (rollback) adına tamamen tek bir işlem (transaction) altında çalışan PL/pgSQL saklı yordamı (`sp_run_etl`) ile yürütülmüştür.

### Ayıklama ve Reddetme (Data Rejection)
İş mantığı kuralları gereği, oyuncu benzersiz ID bilgisi eksik olan veya sayısal olmayan, oyuncu ismi boş bırakılmış kayıtlar hatalı kabul edilerek `rejected_records` tablosuna raporlama sebebiyle yazılmakta ve ETL sürecinden elenmektedir.

### Dönüştürme ve Standartlaştırma (Transformation)
* **Boy ve Kilo Dönüşümü:** `CASE WHEN` yapısı ve metin fonksiyonları kullanılarak boy inç cinsindeyse `(Feet * 30.48) + (Inches * 2.54)` formülüyle cm'ye çevrilmiş, kilolar ise libre cinsindeyse `0.453592` ile çarpılarak kg birimine standartlaştırılmıştır.
* **Finansal Değerlerin Temizliği:** E-Ticaret ve Finans projelerinde sıkça kullanılan metotla, metin tabanlı parasal alanlardaki Euro sembolleri atılmış, 'M' içeren değerler 1.000.000, 'K' içeren değerler ise 1.000 ile çarpılarak matematiksel aritmetik işlemlere uygun `DECIMAL` tipine dönüştürülmüştür.
* **Kulüp ve Kontrat Ayrıştırma:** Hücre başlarındaki boşluklar `trim(both E'\r\n\t ' from ...)` ile temizlenmiş, ardından yeni satır karakterlerine göre bölünerek Kulüp Adı, Kontrat Başlangıç Yılı ve Kontrat Bitiş Yılı olarak 3 farklı kolona ayrıştırılmıştır. Kontratı olmayanlar 'Free Agent' olarak işaretlenmiştir.

### Tekilleştirme (Deduplication)
Aynı oyuncu ID'sine sahip mükerrer satırların hedef tabloda hata vermesini engellemek amacıyla, `DISTINCT ON (player_id)` ifadesi kullanılarak her bir oyuncunun sadece en yüksek genel rating değerine sahip olan tekil kaydı işlenmiştir. Bu sayede hedef tabloya yükleme aşamasında çakışmaların (ON CONFLICT) önüne geçilmiştir.

---

## Veri Kalitesi Raporlaması ve Analiz

ETL sürecinin bitiminde, üretilen verilerin kalitesini ölçmek ve iş analitiği raporları sunabilmek adına şu veri görünümleri (Views) oluşturulmuştur:

* **vw_etl_summary:** ETL'in genel çalışma başarısını, toplam ham veri adedini, kaç verinin başarıyla yüklendiğini ve yüzde kaçlık bir başarı oranına ulaştığını raporlar.
* **vw_data_quality_metrics:** Veritabanındaki toplam hata ve mükerrerlik oranlarını sayısal metriklerle sunar.
* **vw_club_stats:** Temizlenen veriler üzerinde kulüpler bazında ortalama oyuncu yaşını, ortalama rating seviyelerini ve toplam kulüp bütçe/maaş analizlerini hesaplar.
* **vw_nationality_stats:** Ülkelere göre futbolcu gücü dağılımını gösterir.

Lionel Messi gibi örnek oyuncuların temizlik öncesindeki inç/libre ve metin tabanlı finansal verileri ile temizlendikten sonraki cm/kg ve sayısal finansal verileri karşılaştırılarak veri dönüşüm başarısı doğrulanmıştır.

---

## Sonuç

Bu projede, gerçek bir veri kümesi olan FIFA 21 veri seti üzerinde uygulanan ETL süreci, veri ambarı sistemlerinde veri temizliğinin önemini pratik olarak ortaya koymuştur. SQL tabanlı temizlik ve dönüştürme kuralları sayesinde, biçimsel olarak son derece kirli, metrik sistemi düzensiz ve mükerrer olan 18.979 oyuncu kaydı, 1 saniye gibi kısa bir sürede ilişkisel bir veri tabanına hatasız şekilde aktarılmıştır. 

Çalışma sonucunda, veritabanı seviyesinde optimize edilmiş sorguların ve saklı yordamların kullanımıyla veri taşıma ve temizleme işlemlerinin hem transaction güvenliği içinde yapılması hem de milisaniyeler bazında performans göstermesi sağlanmıştır. Temizlenen veri seti üzerinden üretilen analitik raporlar, işletmeler için doğru ve güvenilir veri analizlerinin temelini oluşturmaktadır.
