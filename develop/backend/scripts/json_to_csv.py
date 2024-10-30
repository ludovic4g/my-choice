import json
import csv

def convert_json_to_csv(json_file_path, csv_file_path):
    # Leggi il file JSON
    with open(json_file_path, 'r', encoding='utf-8') as json_file:
        dati = json.load(json_file)

    # Trova tutte le chiavi uniche per le intestazioni CSV
    chiavi = list(dati[0].keys()) if dati else []

    # Scrivi il file CSV
    with open(csv_file_path, 'w', encoding='utf-8', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=chiavi)
        writer.writeheader()
        writer.writerows(dati)

# Percorso al file JSON di input e al file CSV di output
json_file_path = 'develop/backend/assets/dati_centri.json'
csv_file_path = 'develop/backend/assets/dati_centri.csv'

# Esegui la conversione
convert_json_to_csv(json_file_path, csv_file_path)
