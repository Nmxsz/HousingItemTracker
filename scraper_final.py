#!/usr/bin/env python3
"""
WoWDB Housing Decor Scraper - Final Version
Nutzt die mb-3 div-Struktur für präzise Extraktion
"""

import json
import time
import re
import os
import requests
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
from PIL import Image
import io

BASE_URL = "https://housing.wowdb.com"
DECOR_LIST_URL = f"{BASE_URL}/decor/#grid-view"
TEXTURES_DIR = Path("textures/vendor_maps")

def setup_driver(headless=True):
    """Setup Chrome WebDriver"""
    print("Initialisiere Chrome WebDriver...")
    options = Options()
    if headless:
        options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
    
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    return driver

def escape_lua_string(text):
    """Escaped einen String für Lua"""
    if not text:
        return ""
    return str(text).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")

def download_and_convert_map(map_url, vendor_name, location):
    """Lädt Karten-Bild herunter und konvertiert zu TGA"""
    if not map_url:
        return None
    
    try:
        # Erstelle Textures-Ordner falls nicht vorhanden
        TEXTURES_DIR.mkdir(parents=True, exist_ok=True)
        
        # Extrahiere Dateinamen aus der URL (z.B. "2351_razorwind_shores.jpg")
        # Das stellt sicher, dass verschiedene Karten für die gleiche Zone unterschiedliche Namen haben
        url_filename = map_url.split('/')[-1]  # Holt den letzten Teil der URL
        base_filename = url_filename.rsplit('.', 1)[0]  # Entfernt .jpg/.png
        
        # Säubere den Dateinamen
        safe_filename = re.sub(r'[^\w\s-]', '_', base_filename).lower()
        filename = f"map_{safe_filename}"
        
        # Prüfe ob schon existiert
        tga_path = TEXTURES_DIR / f"{filename}.tga"
        if tga_path.exists():
            # Gib relativen Pfad zurück
            return f"Interface\\AddOns\\HousingItemTracker\\textures\\vendor_maps\\{filename}"
        
        # Download Bild
        response = requests.get(map_url, timeout=10)
        response.raise_for_status()
        
        # Konvertiere zu TGA
        img = Image.open(io.BytesIO(response.content))
        
        # Resize falls zu groß (max 512x512 für WoW Performance)
        max_size = 512
        if img.width > max_size or img.height > max_size:
            img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        
        # Konvertiere zu RGBA falls nötig
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Speichere als TGA
        img.save(tga_path, format='TGA')
        
        print(f"    Karte gespeichert: {filename}.tga")
        
        # Gib WoW-Pfad zurück (ohne .tga Extension, WoW fügt das automatisch hinzu)
        return f"Interface\\AddOns\\HousingItemTracker\\textures\\vendor_maps\\{filename}"
        
    except Exception as e:
        print(f"    Fehler beim Herunterladen der Karte: {e}")
        return None

def extract_item_id(url):
    """Extrahiert Item-ID aus URL"""
    match = re.search(r'/decor/(\d+)', url)
    return int(match.group(1)) if match else None

def collect_item_urls(driver, max_pages=96):
    """Sammelt alle Item-URLs von allen Seiten"""
    all_items = {}
    seen_ids = set()
    
    print(f"Sammle Items von {max_pages} Seiten...")
    
    for page_num in range(1, max_pages + 1):
        page_url = f"{BASE_URL}/decor/?page={page_num}#grid-view"
        print(f"\n[Seite {page_num}/{max_pages}] {page_url}")
        
        try:
            driver.get(page_url)
            
            # Warte auf Items
            try:
                WebDriverWait(driver, 15).until(
                    EC.presence_of_element_located((By.XPATH, "//a[contains(@href, '/decor/')]"))
                )
            except:
                print(f"  Timeout - keine Items gefunden")
                continue
            
            time.sleep(1)  # Kurze Pause für JavaScript
            
            # Scrolle einmal nach unten um lazy-load Items zu laden
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(0.5)
            
            # Sammle Item-Links von dieser Seite
            links = driver.find_elements(By.XPATH, "//a[contains(@href, '/decor/')]")
            
            page_items = 0
            for link in links:
                try:
                    href = link.get_attribute('href')
                    item_id = extract_item_id(href)
                    
                    if item_id and item_id not in seen_ids:
                        seen_ids.add(item_id)
                        all_items[item_id] = href
                        page_items += 1
                except:
                    continue
            
            print(f"  {page_items} neue Items gefunden (Gesamt: {len(all_items)})")
            
            # Kleine Pause zwischen Seiten
            time.sleep(0.5)
            
        except Exception as e:
            print(f"  Fehler auf Seite {page_num}: {e}")
            continue
    
    print(f"\n{'='*70}")
    print(f"GESAMT: {len(all_items)} eindeutige Items von {max_pages} Seiten")
    print(f"{'='*70}\n")
    return all_items

def parse_vendor_div(div_text, div_soup):
    """Parst ein Vendor-DIV und extrahiert alle Vendor-Informationen"""
    vendors = []
    
    if not div_soup:
        return vendors
    
    # Finde alle NPC-Links (Vendor-Namen)
    npc_links = div_soup.find_all('a', href=re.compile(r'/npcs/\d+'))
    
    for npc_link in npc_links:
        vendor_name = npc_link.get_text(strip=True)
        if not vendor_name:
            continue
        
        # Finde das übergeordnete Element (oft ein div oder span)
        # Der Preis und die Location sind Geschwister-Elemente
        vendor_container = npc_link.find_parent('div', class_='mb-3') or npc_link.find_parent()
        
        location = None
        price = None
        currency = None
        map_image = None
        waypoint = None
        coord_x = None
        coord_y = None
        
        if vendor_container:
            # LOCATION - suche nach Text in Klammern (...)
            container_text = vendor_container.get_text()
            location_match = re.search(r'\(([^)]+)\)', container_text)
            if location_match:
                location = location_match.group(1).strip()
            
            # PREIS - suche nach <strong> Tag mit Zahl
            strong_tag = vendor_container.find('strong')
            if strong_tag:
                price_text = strong_tag.get_text(strip=True)
                price_match = re.search(r'(\d+)', price_text)
                if price_match:
                    price = int(price_match.group(1))
            
            # CURRENCY - suche nach Currency-Link oder Gold-Image
            # Option 1: Currency-Link (z.B. Community Coupons, Honor)
            currency_link = vendor_container.find('a', href=re.compile(r'/currencies/\d+'))
            if currency_link:
                currency = currency_link.get_text(strip=True)
            else:
                # Option 2: Gold-Image
                gold_img = vendor_container.find('img', alt=re.compile(r'gold', re.I))
                if gold_img:
                    currency = "Gold"
                    # Bei Gold ist der Preis oft direkt vor dem Image
                    if not price:
                        # Suche nach Zahlen vor dem Image
                        img_parent = gold_img.find_parent()
                        if img_parent:
                            img_text = img_parent.get_text()
                            price_match = re.search(r'(\d+)', img_text)
                            if price_match:
                                price = int(price_match.group(1))
            
            # MAP IMAGE - suche nach Karten-Bildern (oft in einem img oder als background-image)
            # Vendor Location Maps haben oft "map" im Dateinamen
            map_imgs = vendor_container.find_all('img', src=re.compile(r'map|location', re.I))
            if map_imgs:
                map_img = map_imgs[0]
                map_image_url = map_img.get('src')
                
                # Extrahiere Koordinaten aus map-pin div
                map_pin = vendor_container.find('div', class_='map-pin')
                if map_pin:
                    coord_x_str = map_pin.get('data-x')
                    coord_y_str = map_pin.get('data-y')
                    
                    if coord_x_str and coord_y_str:
                        try:
                            coord_x = float(coord_x_str)
                            coord_y = float(coord_y_str)
                        except:
                            pass
                
                # Konvertiere zu absoluter URL
                if map_image_url and not map_image_url.startswith('http'):
                    if not map_image_url.startswith('//'):
                        map_image_url = f"https://housing.wowdb.com{map_image_url}" if map_image_url.startswith('/') else f"https://housing.wowdb.com/{map_image_url}"
                    else:
                        map_image_url = f"https:{map_image_url}"
                
                # Download und konvertiere zu TGA
                map_image = download_and_convert_map(map_image_url, vendor_name, location)
            else:
                map_image = None
            
            # WAYPOINT - suche nach Koordinaten (Format: /way 12.3 45.6)
            waypoint_match = re.search(r'/way\s+([\d.]+)\s+([\d.]+)', vendor_container.get_text())
            if waypoint_match:
                waypoint = f"/way {waypoint_match.group(1)} {waypoint_match.group(2)}"
                # Falls wir noch keine Koordinaten haben, nutze die aus dem Waypoint
                if not coord_x and not coord_y:
                    try:
                        coord_x = float(waypoint_match.group(1))
                        coord_y = float(waypoint_match.group(2))
                    except:
                        pass
        
        vendor_info = {
            "name": vendor_name,
            "location": location,
            "price": price,
            "currency": currency,
            "mapTexture": map_image,  # WoW Texture Pfad (ohne .tga)
            "waypoint": waypoint,
            "coordX": coord_x,
            "coordY": coord_y
        }
        
        # Verhindere Duplikate (gleicher Name + Location)
        is_duplicate = any(
            v["name"] == vendor_info["name"] and v["location"] == vendor_info["location"]
            for v in vendors
        )
        
        if not is_duplicate:
            vendors.append(vendor_info)
    
    return vendors

def scrape_item_details(driver, item_id, item_url):
    """Scraped Details eines einzelnen Items"""
    item_data = {
        "id": item_id,
        "name": "",
        "category": None,
        "subcategory": None,
        "budget_cost": None,
        "sources": [],
        "vendors": [],
        "materials": [],
        "achievement": None,
        "quest": None,
        "profession": None
    }
    
    try:
        driver.get(item_url)
        
        # Warte auf H1
        try:
            WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, "h1")))
        except:
            return item_data
        
        time.sleep(2)
        
        # Scrolle nach unten um alle Sources zu laden
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(1)
        
        # Parse HTML
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        
        # NAME
        h1 = soup.find('h1')
        if h1:
            item_data["name"] = h1.get_text(strip=True)
        
        # Alle mb-3 Divs analysieren
        mb3_divs = soup.find_all('div', class_='mb-3')
        
        for div in mb3_divs:
            div_text = div.get_text(separator=' ', strip=True)
            
            if not div_text:
                continue
            
            # VENDOR
            if div_text.startswith('Vendor:'):
                if "Vendor" not in item_data["sources"]:
                    item_data["sources"].append("Vendor")
                
                # Parse Vendors (übergebe auch das soup-Element für Alternative-Parsing)
                vendors = parse_vendor_div(div_text, div)
                item_data["vendors"].extend(vendors)
            
            # ACHIEVEMENT
            elif div_text.startswith('Achievement:'):
                if "Achievement" not in item_data["sources"]:
                    item_data["sources"].append("Achievement")
                # Extrahiere Achievement-Name
                achievement_link = div.find('a', href=re.compile(r'/achievements/'))
                if achievement_link:
                    item_data["achievement"] = achievement_link.get_text(strip=True)
            
            # QUEST
            elif div_text.startswith('Quest:'):
                if "Quest" not in item_data["sources"]:
                    item_data["sources"].append("Quest")
                quest_link = div.find('a', href=re.compile(r'/quests/'))
                if quest_link:
                    item_data["quest"] = quest_link.get_text(strip=True)
            
            # CRAFTING/PROFESSION
            elif 'Profession:' in div_text or any(prof in div_text for prof in ['Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'Inscription', 'Jewelcrafting', 'Leatherworking', 'Tailoring']):
                if "Crafting" not in item_data["sources"]:
                    item_data["sources"].append("Crafting")
                for prof in ['Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'Inscription', 'Jewelcrafting', 'Leatherworking', 'Tailoring']:
                    if prof in div_text:
                        item_data["profession"] = prof
                        break
            
            # DROP
            elif 'Drop:' in div_text or 'Dropped by' in div_text:
                if "Drop" not in item_data["sources"]:
                    item_data["sources"].append("Drop")
            
            # TREASURE
            elif 'Treasure:' in div_text:
                if "Treasure" not in item_data["sources"]:
                    item_data["sources"].append("Treasure")
            
            # ENCOUNTER
            elif 'Encounter:' in div_text:
                if "Encounter" not in item_data["sources"]:
                    item_data["sources"].append("Encounter")
            
            # CATEGORY
            elif div_text.startswith('Category:'):
                cat_link = div.find('a')
                if cat_link:
                    item_data["category"] = cat_link.get_text(strip=True)
            
            # SUBCATEGORY
            elif div_text.startswith('Subcategory:'):
                subcat_link = div.find('a')
                if subcat_link:
                    item_data["subcategory"] = subcat_link.get_text(strip=True)
            
            # BUDGET COST
            elif div_text.startswith('Budget Cost:'):
                match = re.search(r'(\d+)', div_text)
                if match:
                    item_data["budget_cost"] = int(match.group(1))
        
        # MATERIALS/REAGENTS (für Crafting-Items)
        # Suche nach "Crafting Reagents" Div oder mb-2 ms-4 Liste
        reagents_div = None
        for div in mb3_divs:
            if 'Reagent' in div.get_text() or 'Material' in div.get_text():
                reagents_div = div
                break
        
        # Alternative: Suche nach ul.list-unstyled mit Item-Links
        if not reagents_div:
            reagents_list = soup.find('ul', class_=re.compile(r'list-unstyled|mb-0'))
            if reagents_list:
                reagents_div = reagents_list
        
        if reagents_div:
            # Finde alle Item-Links (Materials)
            item_links = reagents_div.find_all('a', href=re.compile(r'/items/\d+'))
            
            for item_link in item_links:
                mat_href = item_link.get('href', '')
                mat_id_match = re.search(r'/items/(\d+)', mat_href)
                
                if mat_id_match:
                    mat_id = int(mat_id_match.group(1))
                    mat_name = item_link.get_text(strip=True)
                    
                    # Suche nach Quantity (Format: "5x" oder "x5" oder "(5)")
                    mat_li = item_link.find_parent('li')
                    quantity = 1
                    
                    if mat_li:
                        li_text = mat_li.get_text()
                        # Suche nach verschiedenen Quantity-Formaten
                        qty_match = re.search(r'(\d+)\s*x|x\s*(\d+)|\((\d+)\)', li_text, re.I)
                        if qty_match:
                            quantity = int(qty_match.group(1) or qty_match.group(2) or qty_match.group(3))
                    
                    # Verhindere Duplikate
                    if not any(m["id"] == mat_id for m in item_data["materials"]):
                        item_data["materials"].append({
                            "id": mat_id,
                            "name": mat_name,
                            "quantity": quantity
                        })
        
        # Falls Crafting-Source aber keine Materials gefunden, suche breiter
        if "Crafting" in item_data["sources"] and not item_data["materials"]:
            all_item_links = soup.find_all('a', href=re.compile(r'/items/\d+'))
            for item_link in all_item_links[:10]:  # Limitiere auf erste 10
                mat_id_match = re.search(r'/items/(\d+)', item_link.get('href', ''))
                if mat_id_match:
                    mat_id = int(mat_id_match.group(1))
                    mat_name = item_link.get_text(strip=True)
                    if mat_name and not any(m["id"] == mat_id for m in item_data["materials"]):
                        item_data["materials"].append({
                            "id": mat_id,
                            "name": mat_name,
                            "quantity": 1
                        })
        
        print(f"[{item_id}] {item_data['name']}")
        if item_data["sources"]:
            print(f"  Sources: {', '.join(item_data['sources'])}")
        if item_data["vendors"]:
            print(f"  Vendors: {len(item_data['vendors'])}")
        if item_data["budget_cost"]:
            print(f"  Budget: {item_data['budget_cost']}")
        if item_data["category"]:
            print(f"  Category: {item_data['category']} > {item_data['subcategory']}")
        
    except Exception as e:
        print(f"  Fehler: {e}")
    
    return item_data

def generate_lua_database(items_data):
    """Generiert Lua-Datenbank"""
    lua_content = """-- Housing Item Database
-- Auto-generated by scraper_final.py

HousingItemTrackerDB = {
    version = 2,
    items = {
        decorItems = {
"""
    
    # Sammle Materials
    all_materials = set()
    for item in items_data.values():
        for mat in item.get("materials", []):
            all_materials.add(mat["id"])
    
    # Schreibe Items
    for item_id in sorted(items_data.keys()):
        item = items_data[item_id]
        lua_content += f"            [{item_id}] = {{\n"
        lua_content += f"                name = \"{escape_lua_string(item.get('name', 'Unknown'))}\",\n"
        
        if item.get("budget_cost"):
            lua_content += f"                decorCost = {item['budget_cost']},\n"
        if item.get("category"):
            lua_content += f"                category = \"{escape_lua_string(item['category'])}\",\n"
        if item.get("subcategory"):
            lua_content += f"                subcategory = \"{escape_lua_string(item['subcategory'])}\",\n"
        
        if item.get("sources"):
            lua_content += f"                sources = {{\n"
            for source in item["sources"]:
                lua_content += f"                    \"{escape_lua_string(source)}\",\n"
            lua_content += f"                }},\n"
        
        if item.get("vendors"):
            lua_content += f"                vendors = {{\n"
            for vendor in item["vendors"]:
                lua_content += f"                    {{\n"
                lua_content += f"                        name = \"{escape_lua_string(vendor['name'])}\",\n"
                if vendor.get("location"):
                    lua_content += f"                        location = \"{escape_lua_string(vendor['location'])}\",\n"
                if vendor.get("price"):
                    lua_content += f"                        price = {vendor['price']},\n"
                if vendor.get("currency"):
                    lua_content += f"                        currency = \"{escape_lua_string(vendor['currency'])}\",\n"
                if vendor.get("mapTexture"):
                    lua_content += f"                        mapTexture = \"{escape_lua_string(vendor['mapTexture'])}\",\n"
                if vendor.get("coordX") is not None:
                    lua_content += f"                        coordX = {vendor['coordX']},\n"
                if vendor.get("coordY") is not None:
                    lua_content += f"                        coordY = {vendor['coordY']},\n"
                if vendor.get("waypoint"):
                    lua_content += f"                        waypoint = \"{escape_lua_string(vendor['waypoint'])}\",\n"
                lua_content += f"                    }},\n"
            lua_content += f"                }},\n"
        
        if item.get("profession"):
            lua_content += f"                profession = \"{escape_lua_string(item['profession'])}\",\n"
        if item.get("achievement"):
            lua_content += f"                achievement = \"{escape_lua_string(item['achievement'])}\",\n"
        if item.get("quest"):
            lua_content += f"                quest = \"{escape_lua_string(item['quest'])}\",\n"
        
        # Materials (für Crafting)
        if item.get("materials"):
            lua_content += f"                materials = {{\n"
            for material in item["materials"]:
                lua_content += f"                    {{\n"
                lua_content += f"                        id = {material['id']},\n"
                lua_content += f"                        name = \"{escape_lua_string(material['name'])}\",\n"
                lua_content += f"                        quantity = {material.get('quantity', 1)},\n"
                lua_content += f"                    }},\n"
            lua_content += f"                }},\n"
        
        lua_content += f"            }},\n"
    
    lua_content += "        },\n        materials = {\n"
    
    for mat_id in sorted(all_materials):
        lua_content += f"            [{mat_id}] = true,\n"
    
    lua_content += "        },\n    },\n}\n"
    
    return lua_content

def main():
    print("=" * 70)
    print("WoWDB Housing Scraper - Final Version")
    print("=" * 70)
    print()
    print("Dieser Scraper wird ALLE Housing Items von WoWDB scrapen.")
    print("Geschätzte Dauer: 30-60 Minuten für ~2296 Items")
    print("=" * 70)
    print()
    
    driver = setup_driver(headless=True)
    
    try:
        # Schritt 1: Sammle alle Item-URLs von allen 96 Seiten
        item_urls = collect_item_urls(driver, max_pages=96)
        
        if not item_urls:
            print("Keine Items gefunden!")
            return
        
        # Schritt 2: Scrape jedes Item
        all_data = {}
        total = len(item_urls)
        
        for idx, (item_id, url) in enumerate(item_urls.items(), 1):
            print(f"\n[{idx}/{total}] ", end='')
            item_data = scrape_item_details(driver, item_id, url)
            all_data[item_id] = item_data
            
            time.sleep(0.4)  # Pause
            
            # Speichere Fortschritt
            if idx % 50 == 0:
                with open('housing_final_progress.json', 'w', encoding='utf-8') as f:
                    json.dump(all_data, f, indent=2, ensure_ascii=False)
                print(f"\n>>> Fortschritt: {len(all_data)} Items")
        
        # Finale Speicherung
        print("\n\nSpeichere Ergebnisse...")
        
        with open('housing_items_final.json', 'w', encoding='utf-8') as f:
            json.dump(all_data, f, indent=2, ensure_ascii=False)
        
        lua_content = generate_lua_database(all_data)
        with open('HousingItemTrackerDB.lua', 'w', encoding='utf-8') as f:
            f.write(lua_content)
        
        # Statistiken
        items_with_vendors = sum(1 for item in all_data.values() if item.get("vendors"))
        items_with_crafting = sum(1 for item in all_data.values() if "Crafting" in item.get("sources", []))
        items_with_achievement = sum(1 for item in all_data.values() if "Achievement" in item.get("sources", []))
        materials_count = len(set(mat["id"] for item in all_data.values() for mat in item.get("materials", [])))
        
        print("\n" + "=" * 70)
        print("FERTIG!")
        print("=" * 70)
        print(f"Gesamt Items:          {len(all_data)}")
        print(f"Items mit Vendors:     {items_with_vendors}")
        print(f"Items mit Crafting:    {items_with_crafting}")
        print(f"Items mit Achievement: {items_with_achievement}")
        print(f"Eindeutige Materials:  {materials_count}")
        print("=" * 70)
        print("Dateien erstellt:")
        print("  - housing_items_final.json")
        print("  - HousingItemTrackerDB.lua")
        
    except KeyboardInterrupt:
        print("\n\nUnterbrochen!")
    except Exception as e:
        print(f"\nFehler: {e}")
        import traceback
        traceback.print_exc()
    finally:
        driver.quit()

if __name__ == "__main__":
    main()

