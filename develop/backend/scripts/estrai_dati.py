from bs4 import BeautifulSoup
import json

# Funzione per estrarre informazioni da una singola struttura HTML
def estrai_informazioni(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    dati = {}

    # Estrarre il nome dell'ospedale
    titolo = soup.find('h4')
    if titolo:
        dati['Nome'] = titolo.get_text(strip=True)

    # Estrarre tutte le righe della tabella
    righe_tabella = soup.find_all('tr')
    for riga in righe_tabella:
        colonne = riga.find_all('td')
        if len(colonne) == 2:
            chiave = colonne[0].get_text(strip=True)
            valore = colonne[1].get_text(strip=True)

            # Associazioni chiave-valore nel dizionario
            if "Indirizzo" in chiave:
                dati['Indirizzo'] = valore
            elif "Numero" in chiave:
                dati['Numero'] = valore
            elif "Orari" in chiave:
                dati['Orari'] = valore
            elif "I.V.G. FARMACOLOGICA" in chiave:
                dati['ivg_farm'] = valore
            elif "I.V.G. CHIRURGICA" in chiave:
                dati['ivg_chirurgica'] = valore
            elif "I.T.G." in chiave:
                dati['itg'] = valore
            elif "Annotazioni" in chiave:
                dati['Annotazioni'] = valore

    return dati

# Funzione principale per elaborare il file e creare il JSON
def processa_file_html(file_html_path, output_json_path):
    with open(file_html_path, 'r', encoding='utf-8') as file:
        contenuto = file.read()

    # Split per separare le diverse strutture di dati HTML
    sezioni_html = contenuto.split("popup_")  # Adjust if necessary
    lista_dati = []

    for sezione in sezioni_html:
        if "<table" in sezione:
            informazioni = estrai_informazioni(sezione)
            lista_dati.append(informazioni)

    # Scrittura dei dati estratti in formato JSON
    with open(output_json_path, 'w', encoding='utf-8') as json_file:
        json.dump(lista_dati, json_file, ensure_ascii=False, indent=4)

# Percorso al file HTML e al file di output JSON
file_html_path = 'develop/backend/assets/laiga_dataset.html'
output_json_path = 'dati_centri.json'

# Esecuzione della funzione
processa_file_html(file_html_path, output_json_path)
