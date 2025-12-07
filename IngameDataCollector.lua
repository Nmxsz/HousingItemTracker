-- Housing Item Tracker - Ingame Data Collector
-- Sammelt Housing-Item-Informationen direkt aus dem Spiel
-- Exportiert als Lua-Tabelle die kopiert werden kann

local collector = CreateFrame("Frame")
local collectedData = {}

-- Sammelt Informationen über ein Catalog Entry
local function CollectCatalogEntry(entryID)
    if not entryID then return nil end
    
    local entryInfo = C_HousingCatalog.GetCatalogEntryInfo(entryID)
    if not entryInfo then return nil end
    
    local data = {
        id = entryInfo.entryID and entryInfo.entryID.recordID or nil,
        name = entryInfo.name,
        decorCost = entryInfo.placementCost,
        quality = entryInfo.quality,
        -- Sources werden später hinzugefügt
        sources = {},
        vendors = {},
    }
    
    return data
end

-- Durchsucht alle Catalog Entries
local function CollectAllEntries()
    print("Sammle Housing Catalog Daten...")
    
    if not C_HousingCatalog then
        print("Housing Catalog API nicht verfügbar!")
        return
    end
    
    -- Erstelle einen Searcher
    local searcher = C_HousingCatalog.CreateCatalogSearcher()
    if not searcher then
        print("Konnte keinen Catalog Searcher erstellen!")
        return
    end
    
    searcher:SetOwnedOnly(false)
    searcher:SetIncludeMarketEntries(true)
    searcher:SetEditorModeContext(Enum.HouseEditorMode.BasicDecor)
    
    -- Callback wenn Ergebnisse verfügbar sind
    searcher:SetResultsUpdatedCallback(function()
        local results = searcher:GetResults()
        
        print(f"Gefunden: {#results} Catalog Entries")
        
        for _, entryID in ipairs(results) do
            local data = CollectCatalogEntry(entryID)
            if data and data.id then
                collectedData[data.id] = data
            end
        end
        
        print(f"Gesammelt: {#collectedData} Items")
        
        -- Zeige Exportierbare Daten
        print("\n=== KOPIERE DIESEN LUA-CODE ===\n")
        print("HousingItemTrackerCollectedData = {")
        
        for id, data in pairs(collectedData) do
            print(f"    [{id}] = {{")
            print(f"        name = \"{data.name}\",")
            if data.decorCost then
                print(f"        decorCost = {data.decorCost},")
            end
            if data.quality then
                print(f"        quality = {data.quality},")
            end
            print(f"    }},")
        end
        
        print("}")
        print("\n=== ENDE ===\n")
    end)
    
    -- Starte die Suche
    searcher:RunSearch()
end

-- Slash-Command zum Starten
SLASH_HOUSINGCOLLECT1 = "/collecthousing"
SlashCmdList["HOUSINGCOLLECT"] = function(msg)
    CollectAllEntries()
end

print("|cFF00FF00Housing Data Collector geladen!|r")
print("Verwende: |cFFFFFF00/collecthousing|r um Daten zu sammeln")

