@echo off
echo Housing Item Tracker - Datenbank Update
echo ========================================
echo.

REM Pruefe ob Python installiert ist
python --version >nul 2>&1
if errorlevel 1 (
    echo FEHLER: Python ist nicht installiert oder nicht im PATH!
    echo Bitte installiere Python von https://www.python.org/
    pause
    exit /b 1
)

REM Installiere Abhaengigkeiten
echo Installiere Python-Abhaengigkeiten...
pip install -r requirements.txt

if errorlevel 1 (
    echo FEHLER: Konnte Abhaengigkeiten nicht installieren!
    pause
    exit /b 1
)

REM Waehle Scraper-Version
echo.
echo Waehle Scraper-Version:
echo.
echo 1. Enhanced Scraper (mit Source-Info, Vendors, etc.) [EMPFOHLEN]
echo    - Dauert: 30-60 Minuten
echo    - Sammelt: ALLE Informationen (Sources, Vendors, Preis, etc.)
echo.
echo 2. Simple Scraper (nur Materialien)
echo    - Dauert: 5-10 Minuten
echo    - Sammelt: Nur Crafting-Materialien
echo.
choice /C 12 /M "Gib deine Wahl ein"

if errorlevel 2 goto simple
if errorlevel 1 goto enhanced

:enhanced
echo.
echo Starte Enhanced Scraper (dies kann eine Weile dauern)...
echo Bitte warten...
python scraper_final.py

if errorlevel 1 (
    echo FEHLER: Enhanced Scraper ist fehlgeschlagen!
    pause
    exit /b 1
)
goto done

:simple
echo.
echo Starte Simple Scraper...
python scraper.py

if errorlevel 1 (
    echo FEHLER: Simple Scraper ist fehlgeschlagen!
    pause
    exit /b 1
)
goto done

:done
echo.
echo ========================================
echo Fertig! Die Datenbank wurde aktualisiert.
echo Die Datei HousingItemTrackerDB.lua ist jetzt einsatzbereit.
echo ========================================
pause

