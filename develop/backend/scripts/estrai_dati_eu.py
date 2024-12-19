from bs4 import BeautifulSoup
import csv
import os

# Mappa per sostituire i percorsi delle immagini con i nomi dei paesi
country_map = {
    '/static/img/countries/1.png': 'Austria',
    '/static/img/countries/2.png': 'Germany',
    '/static/img/countries/3.png': 'Switzerland',
    '/static/img/countries/4.png': 'Spain',
    '/static/img/countries/5.png': 'France',
    '/static/img/countries/7.png': 'Netherlands',
    '/static/img/countries/8.png': 'Belgium',
    '/static/img/countries/9.png': 'England',
    '/static/img/countries/10.png': 'Portugal',
    '/static/img/countries/12.png': 'Norway',
    '/static/img/countries/14.png': 'Italy',
    '/static/img/countries/15.png': 'Ireland'
}

# Leggi il contenuto HTML da un file
with open('centri_europa.html', 'r', encoding='utf-8') as file:
    html_content = file.read()

# Parse il contenuto HTML con BeautifulSoup
soup = BeautifulSoup(html_content, 'html.parser')

def extract_clinic_info(soup):
    clinics_by_country = {}

    # Trova tutte le righe della tabella che contengono i dati delle cliniche
    rows = soup.find_all('tr', role='row')
    for row in rows:
        cells = row.find_all('td')
        if len(cells) < 5:
            continue  # Salta righe incomplete

        # Estrai i dettagli dalle celle
        name = cells[0].get_text(strip=True)
        address = cells[1].get_text(strip=True)
        zip_city = cells[2].get_text(strip=True).split(' ', 1)
        zip_code = zip_city[0] if len(zip_city) > 0 else 'N/A'
        city = zip_city[1] if len(zip_city) > 1 else 'N/A'
        flag_img = cells[3].find('img')
        country_src = flag_img['src'] if flag_img else 'N/A'
        country = country_map.get(country_src, 'Unknown')

        # Salta i centri relativi all'Italia
        if country == 'Italy':
            continue

        region = cells[4].get_text(strip=True)

        clinic = {
            'Nome': name,
            'Indirizzo': address,
            'Codice Postale': zip_code,
            'Città': city,
            'Paese': country,
            'Regione': region
        }

        if country not in clinics_by_country:
            clinics_by_country[country] = []
        clinics_by_country[country].append(clinic)

    return clinics_by_country

def save_to_csv_by_country(clinics_by_country):
    keys = ['Nome', 'Indirizzo', 'Codice Postale', 'Città', 'Paese', 'Regione']

    # Crea una directory per i file CSV
    output_dir = 'clinics_by_country'
    os.makedirs(output_dir, exist_ok=True)

    for country, clinics in clinics_by_country.items():
        filename = os.path.join(output_dir, f"{country}_centri.csv")
        with open(filename, mode='w', newline='', encoding='utf-8') as file:
            writer = csv.DictWriter(file, fieldnames=keys)
            writer.writeheader()
            writer.writerows(clinics)
        print(f"Dati salvati per {country} in {filename}")

# Esegui la funzione per estrarre le informazioni
clinics_by_country = extract_clinic_info(soup)

# Salva i risultati in file CSV per ogni paese
save_to_csv_by_country(clinics_by_country)
