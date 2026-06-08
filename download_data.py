import urllib.request
import os

url = "https://raw.githubusercontent.com/krishan0520/Data_cleaning/master/fifa21_raw_data.csv"
output_dir = "data"
output_file = os.path.join(output_dir, "fifa21_raw_data.csv")

try:
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"'{output_dir}' dizini oluşturuldu.")
        
    print(f"FIFA 21 ham veri kümesi indiriliyor:\nURL: {url}")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response, open(output_file, 'wb') as out_file:
        data = response.read()
        out_file.write(data)
    print(f"Başarılı! Dosya kaydedildi: {output_file}")
    print(f"Dosya boyutu: {len(data) / 1024 / 1024:.2f} MB")
except Exception as e:
    print("Hata:", e)
