#!/bin/bash

echo "Housing Item Tracker - Datenbank Update"
echo "========================================"
echo ""

# Prüfe ob Python installiert ist
if ! command -v python3 &> /dev/null; then
    echo "FEHLER: Python3 ist nicht installiert!"
    echo "Bitte installiere Python3"
    exit 1
fi

# Installiere Abhängigkeiten
echo "Installiere Python-Abhängigkeiten..."
pip3 install -r requirements.txt

if [ $? -ne 0 ]; then
    echo "FEHLER: Konnte Abhängigkeiten nicht installieren!"
    exit 1
fi

# Führe Scraper aus
echo ""
echo "Starte Scraper..."
python3 scraper.py

if [ $? -ne 0 ]; then
    echo "FEHLER: Scraper ist fehlgeschlagen!"
    exit 1
fi

echo ""
echo "Fertig! Die Datenbank wurde aktualisiert."
echo "Kopiere HousingItemTrackerDB.lua ins Addon-Verzeichnis."

