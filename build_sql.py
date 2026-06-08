import csv
import os

csv_path = "data/fifa21_raw_data.csv"
sql_path = "01_staging_setup.sql"

print("Reading CSV and generating SQL Staging file...")

# Columns list mapping to SQL safe names (no spaces, special chars removed like ↓)
sql_columns = [
    "photoUrl", "LongName", "playerUrl", "Nationality", "Positions", "Name", "Age", "OVA", "POT", 
    "Team_Contract", "ID", "Height", "Weight", "foot", "BOV", "BP", "Growth", "Joined", "Loan_Date_End", 
    "Value", "Wage", "Release_Clause", "Attacking", "Crossing", "Finishing", "Heading_Accuracy", 
    "Short_Passing", "Volleys", "Skill", "Dribbling", "Curve", "FK_Accuracy", "Long_Passing", 
    "Ball_Control", "Movement", "Acceleration", "Sprint_Speed", "Agility", "Reactions", "Balance", 
    "Power", "Shot_Power", "Jumping", "Stamina", "Strength", "Long_Shots", "Mentality", "Aggression", 
    "Interceptions", "Positioning", "Vision", "Penalties", "Composure", "Defending", "Marking", 
    "Standing_Tackle", "Sliding_Tackle", "Goalkeeping", "GK_Diving", "GK_Handling", "GK_Kicking", 
    "GK_Positioning", "GK_Reflexes", "Total_Stats", "Base_Stats", "WF", "SM", "AW", "DW", "IR", 
    "PAC", "SHO", "PAS", "DRI", "DEF", "PHY", "Hits"
]

create_table_sql = """-- ============================================================================
-- 01_staging_setup.sql (Gerçek FIFA 21 Veri Kümesi)
-- ----------------------------------------------------------------------------
-- Amaç: Ham FIFA 21 verilerinin yükleneceği Staging tablosunun oluşturulması.
-- ============================================================================

DROP TABLE IF EXISTS staging_fifa21 CASCADE;

CREATE TABLE staging_fifa21 (
"""

for i, col in enumerate(sql_columns):
    comma = "," if i < len(sql_columns) - 1 else ""
    create_table_sql += f"    {col} TEXT{comma}\n"
create_table_sql += ");\n\n"

try:
    with open(csv_path, 'r', encoding='utf-8') as infile, open(sql_path, 'w', encoding='utf-8') as outfile:
        # Write header
        outfile.write(create_table_sql)
        
        reader = csv.reader(infile)
        # Skip header
        headers = next(reader)
        
        chunk = []
        chunk_size = 500
        total_rows = 0
        
        outfile.write("-- FIFA 21 Kayıtlarının Eklenmesi\n")
        
        for row in reader:
            # Escape single quotes and handle newlines/null values
            escaped_row = []
            for val in row:
                if val is None or val == '':
                    escaped_row.append("NULL")
                else:
                    # Escape single quotes for SQL insertion
                    escaped_val = val.replace("'", "''")
                    escaped_row.append(f"'{escaped_val}'")
            
            chunk.append(f"({', '.join(escaped_row)})")
            total_rows += 1
            
            if len(chunk) == chunk_size:
                insert_sql = f"INSERT INTO staging_fifa21 ({', '.join(sql_columns)}) VALUES\n"
                insert_sql += ",\n".join(chunk) + ";\n"
                outfile.write(insert_sql)
                chunk = []
                
        # Write remaining
        if chunk:
            insert_sql = f"INSERT INTO staging_fifa21 ({', '.join(sql_columns)}) VALUES\n"
            insert_sql += ",\n".join(chunk) + ";\n"
            outfile.write(insert_sql)
            
        # Count check
        outfile.write(f"\nSELECT 'staging_fifa21' AS tablo_adi, COUNT(*) AS kayit_sayisi FROM staging_fifa21;\n")
        
    print(f"Başarılı! SQL dosyası '{sql_path}' oluşturuldu. Toplam satır: {total_rows}")
except Exception as e:
    print("Hata:", e)
