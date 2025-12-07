-- Housing Item Tracker
-- Markiert Items, die für Housing-Crafting benötigt werden

local addonName = "HousingItemTracker"
local HousingItemTracker = CreateFrame("Frame")

-- Frame für Vendor-Karten-Anzeige
local VendorMapFrame = CreateFrame("Frame", "HousingVendorMapFrame", UIParent)
VendorMapFrame:SetSize(256, 256)
VendorMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
VendorMapFrame:Hide()
VendorMapFrame:SetFrameStrata("TOOLTIP")
VendorMapFrame:SetFrameLevel(1000)

-- Background
VendorMapFrame.bg = VendorMapFrame:CreateTexture(nil, "BACKGROUND")
VendorMapFrame.bg:SetAllPoints()
VendorMapFrame.bg:SetColorTexture(0, 0, 0, 0.8)

-- Border
VendorMapFrame.border = VendorMapFrame:CreateTexture(nil, "BORDER")
VendorMapFrame.border:SetAllPoints()
VendorMapFrame.border:SetColorTexture(0.3, 0.3, 0.3, 1)
VendorMapFrame.border:SetPoint("TOPLEFT", -1, 1)
VendorMapFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)

-- Map Texture
VendorMapFrame.texture = VendorMapFrame:CreateTexture(nil, "ARTWORK")
VendorMapFrame.texture:SetPoint("TOPLEFT", 4, -4)
VendorMapFrame.texture:SetPoint("BOTTOMRIGHT", -4, 4)

-- Map Pin (eigene Texture)
VendorMapFrame.pin = VendorMapFrame:CreateTexture(nil, "OVERLAY")
VendorMapFrame.pin:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\map-pin")
VendorMapFrame.pin:SetSize(32, 32)  -- Etwas größer für bessere Sichtbarkeit
VendorMapFrame.pin:Hide()

-- Title
VendorMapFrame.title = VendorMapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
VendorMapFrame.title:SetPoint("TOP", 0, -8)
VendorMapFrame.title:SetTextColor(1, 0.82, 0)

-- Close Button
VendorMapFrame.close = CreateFrame("Button", nil, VendorMapFrame, "UIPanelCloseButton")
VendorMapFrame.close:SetPoint("TOPRIGHT", 2, 2)

-- Funktion zum Anzeigen der Karte
function VendorMapFrame:ShowMap(mapTexture, locationName, coordX, coordY)
    if not mapTexture then return end
    
    self.texture:SetTexture(mapTexture)
    self.title:SetText(locationName or "Vendor Location")
    
    -- Intelligente Positionierung neben dem GameTooltip
    local tooltip = GameTooltip

   -- Speichere Tooltip-Referenz
   self.anchoredTooltip = GameTooltip
    
   -- Intelligente Positionierung
   self:UpdatePosition()
    
    -- Zeige Map Pin falls Koordinaten vorhanden
    if coordX and coordY then
        -- Konvertiere % Koordinaten (0-100) zu Pixel-Position auf der Karte
        -- Die Karte ist 256x256, aber wir haben 4px Padding
        local mapWidth = 256 - 8  -- 4px links + 4px rechts
        local mapHeight = 256 - 8  -- 4px oben + 4px unten
        
        -- X/Y sind in Prozent (0-100), konvertiere zu Pixel-Offset
        local pixelX = (coordX / 100) * mapWidth
        local pixelY = (coordY / 100) * mapHeight
        
        -- Setze Pin-Position (relativ zur Karte)
        -- Y muss invertiert werden (0 = oben in WoW)
        self.pin:ClearAllPoints()
        self.pin:SetPoint("CENTER", self.texture, "TOPLEFT", pixelX, -pixelY)
        self.pin:Show()
    else
        self.pin:Hide()
    end
    
    self:Show()
end

-- Update Position Funktion
function VendorMapFrame:UpdatePosition()
    local tooltip = self.anchoredTooltip or GameTooltip
    
    if not tooltip or not tooltip:IsShown() then
        return
    end
    
    self:ClearAllPoints()
    
    -- Hole Tooltip-Position und Größe
    local tooltipLeft = tooltip:GetLeft()
    local tooltipRight = tooltip:GetRight()
    local tooltipTop = tooltip:GetTop()
    
    if not tooltipLeft or not tooltipRight or not tooltipTop then
        -- Fallback Position
        self:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
        return
    end
    
    -- Bildschirm-Breite
    local screenWidth = GetScreenWidth()
    
    -- Map-Breite
    local mapWidth = self:GetWidth()
    
    -- Prüfe ob Platz rechts vom Tooltip ist
    local spaceOnRight = screenWidth - tooltipRight
    
    if spaceOnRight >= (mapWidth + 20) then
        -- Genug Platz rechts - zeige rechts
        self:SetPoint("TOPLEFT", tooltip, "TOPRIGHT", 15, 0)
    else
        -- Kein Platz rechts - versuche links
        local spaceOnLeft = tooltipLeft
        
        if spaceOnLeft >= (mapWidth + 20) then
            -- Platz links - zeige links
            self:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -15, 0)
        else
            -- Kein Platz links oder rechts - zeige unterhalb
            self:SetPoint("TOP", tooltip, "BOTTOM", 0, -15)
        end
    end
end

-- OnUpdate: Verstecke wenn Tooltip verschwindet und aktualisiere Position
VendorMapFrame:SetScript("OnUpdate", function(self, elapsed)
    if not self.anchoredTooltip or not self.anchoredTooltip:IsShown() then
        self:Hide()
        self.anchoredTooltip = nil
    else
        -- Aktualisiere Position falls Tooltip sich bewegt hat
        if not self.updateTimer then
            self.updateTimer = 0
        end
        
        self.updateTimer = self.updateTimer + elapsed
        
        -- Aktualisiere Position alle 0.1 Sekunden
        if self.updateTimer >= 0.1 then
            self.updateTimer = 0
            self:UpdatePosition()
        end
    end
end)

-- Lade die Datenbank (wird vom Scraper generiert)
if not HousingItemTrackerDB then
    HousingItemTrackerDB = {
        version = 1,
        items = {
            materials = {},
            decorItems = {},
        },
    }
end

local DB = HousingItemTrackerDB.items

-- Prüft ob ein Item für Housing benötigt wird (Material)
local function IsHousingItem(itemId)
    if not itemId then return false end
    return DB.materials[itemId] == true
end

-- Prüft ob ein Item in irgendeinem Decor-Item als Material verwendet wird
local function IsUsedInCrafting(itemId)
    if not itemId or not DB.decorItems then return false end
    
    for decorId, decorInfo in pairs(DB.decorItems) do
        if decorInfo.materials then
            for _, material in ipairs(decorInfo.materials) do
                if material.id == itemId then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Kombinierte Prüfung: Ist es ein Housing-relevantes Item?
local function IsHousingRelated(itemId)
    return IsHousingItem(itemId) or IsUsedInCrafting(itemId)
end

-- Prüft ob ein Item ein Decor-Item ist (optional, für zukünftige Erweiterungen)
local function IsDecorItem(itemId)
    if not itemId then return false end
    return DB.decorItems and DB.decorItems[itemId] ~= nil
end

-- Fügt Tooltip-Text hinzu
local function AddTooltipInfo(tooltip, itemId)
    if not itemId then return end
    
    local isMaterial = IsHousingItem(itemId)
    local isDecor = IsDecorItem(itemId)
    local isUsedInCrafting = IsUsedInCrafting(itemId)
    local decorInfo = DB.decorItems and DB.decorItems[itemId]
    
    if isMaterial or isDecor or isUsedInCrafting then
        tooltip:AddLine(" ") -- Leerzeile
        tooltip:AddLine("|cFF00FF00[Housing]|r", 1, 1, 1)
        
        if isMaterial then
            tooltip:AddLine("Benötigt für Housing-Crafting", 0.8, 0.8, 0.8)
        end
        
        if isUsedInCrafting and not isMaterial then
            -- Zeige in welchen Decor-Items dieses Material verwendet wird
            tooltip:AddLine("Verwendet in Housing-Rezepten", 0.8, 0.8, 0.8)
        end
        
        if decorInfo then
                    
            -- -- Zeige Kategorie
            -- if decorInfo.category then
            --     local categoryText = decorInfo.category
            --     if decorInfo.subcategory then
            --         categoryText = categoryText .. " > " .. decorInfo.subcategory
            --     end
            --     tooltip:AddDoubleLine("Category:", categoryText, 0.8, 0.8, 0.8, 0.7, 0.7, 0.7)
            -- end
            
            -- Zeige Sources
            if decorInfo.sources and #decorInfo.sources > 0 then
                local sourcesText = table.concat(decorInfo.sources, ", ")
                tooltip:AddDoubleLine("Source:", sourcesText, 0.8, 0.8, 0.8, 0.7, 0.9, 1)
            end
            
            -- Zeige Vendor-Informationen
            if decorInfo.vendors and #decorInfo.vendors > 0 then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFFFFD700Vendors:|r", 0.9, 0.9, 0.9)
                
                local firstVendorWithMap = nil
                
                for _, vendor in ipairs(decorInfo.vendors) do
                    local vendorText = "  " .. vendor.name
                    if vendor.location then
                        vendorText = vendorText .. " (" .. vendor.location .. ")"
                    end
                    tooltip:AddLine(vendorText, 0.7, 0.7, 0.7)
                    
                    if vendor.price and vendor.currency then
                        local priceText = "  " .. vendor.price .. " " .. vendor.currency
                        tooltip:AddLine(priceText, 1, 0.82, 0)
                    end
                    
                    -- Zeige Waypoint falls vorhanden
                    if vendor.waypoint then
                        tooltip:AddLine("  |cFF90EE90" .. vendor.waypoint .. "|r", 0.5, 0.9, 0.5)
                    end
                    
                    -- Merke ersten Vendor mit Karte (nur einmal)
                    if vendor.mapTexture and not firstVendorWithMap then
                        firstVendorWithMap = vendor
                    end
                end
                
                -- Zeige "Karte verfügbar" Hinweis nur einmal
                if firstVendorWithMap and firstVendorWithMap.mapTexture then
                                        
                    -- Zeige Karte vom ersten Vendor
                    VendorMapFrame:ShowMap(
                        firstVendorWithMap.mapTexture, 
                        firstVendorWithMap.location,
                        firstVendorWithMap.coordX,
                        firstVendorWithMap.coordY
                    )
                else
                    -- Verstecke Karte wenn keine vorhanden
                    VendorMapFrame:Hide()
                end
            else
                -- Keine Vendors - Karte verstecken
                VendorMapFrame:Hide()
            end
            
            -- Zeige Materials (für Crafting-Items)
            if decorInfo.materials and #decorInfo.materials > 0 then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFF00CCFFMaterials:|r", 0.9, 0.9, 0.9)
                
                for _, material in ipairs(decorInfo.materials) do
                    local matText = "  " .. material.quantity .. "x " .. (material.name or "Item " .. material.id)
                    tooltip:AddLine(matText, 0.8, 0.8, 0.8)
                end
            end
            
            -- Zeige Profession (falls Crafting)
            if decorInfo.profession then
                tooltip:AddDoubleLine("Profession:", decorInfo.profession, 0.8, 0.8, 0.8, 0.7, 0.9, 1)
            end
            
            -- Zeige Achievement (falls vorhanden)
            if decorInfo.achievement then
                tooltip:AddDoubleLine("Achievement:", decorInfo.achievement, 0.8, 0.8, 0.8, 1, 0.5, 0)
            end
            
            -- Zeige Quest (falls vorhanden)
            if decorInfo.quest then
                tooltip:AddDoubleLine("Quest:", decorInfo.quest, 0.8, 0.8, 0.8, 1, 0.8, 0)
            end
        end
    end
end

-- Extrahiert Item-ID aus Item-Link
local function GetItemIdFromLink(itemLink)
    if not itemLink then return nil end
    -- Item-Link Format: |cff9d9d9d|Hitem:12345:0:0:0:0:0:0:0:0|h[Item Name]|h|r
    local itemId = itemLink:match("item:(%d+)")
    return itemId and tonumber(itemId) or nil
end

-- Hook für GameTooltip (moderner Ansatz für Retail WoW)
local function OnTooltipSetItem(tooltip)
    if not tooltip then return end
    
    -- Prüfe ob der Tooltip die GetItem Methode hat
    if tooltip.GetItem then
        local _, itemLink = tooltip:GetItem()
        if itemLink then
            local itemId = GetItemIdFromLink(itemLink)
            if itemId then
                AddTooltipInfo(tooltip, itemId)
            end
        end
    end
end

-- Tooltip-Hook Setup (kompatibel mit modernem WoW)
local function SetupTooltipHooks()
    -- Verwende TooltipDataProcessor für moderne WoW-Versionen (Dragonflight+)
    if TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip then
                OnTooltipSetItem(tooltip)
            end
        end)
    else
        -- Fallback für ältere Versionen (funktioniert aber nicht in Midnight)
        -- Diese Events existieren nicht mehr
    end
end

-- Hook für Bag-Slots (Icon-Markierung) - Vereinfachtes System mit eigener Texture
local function UpdateBagSlotIcon(button)
    if not button then return end
    
    local bagID = button.GetBagID and button:GetBagID()
    local slotID = button.GetID and button:GetID()
    
    if not bagID or not slotID then return end
    
    local itemId = C_Container.GetContainerItemID(bagID, slotID)
    
    -- Zeige Icon für Materialien UND für Items die in Crafting verwendet werden
    if itemId and IsHousingRelated(itemId) then
        -- Erstelle Icon wenn noch nicht vorhanden
        if not button.housingIcon then
            -- Erstelle die Texture als Kind des Buttons
            button.housingIcon = button:CreateTexture(nil, "OVERLAY")
            -- Verwende unsere eigene TGA-Datei
            button.housingIcon:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\decorCost")
            button.housingIcon:SetSize(16, 16)
            button.housingIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            
            -- Setze einen goldenen Farbfilter
            button.housingIcon:SetVertexColor(1, 0.82, 0, 1)  -- Gold
            
            -- Stelle sicher, dass die Texture über allem anderen liegt
            button.housingIcon:SetDrawLayer("OVERLAY", 7)
        end
        button.housingIcon:Show()
    else
        if button.housingIcon then
            button.housingIcon:Hide()
        end
    end
end

-- Update Bank-Buttons (TWW Combined Bank System)
local function UpdateBankSlots()
    -- In TWW gibt es KEINE BankFrameItem Buttons mehr!
    -- Die Bank verwendet jetzt das gleiche System wie normale Bags
    -- ABER: Die Icons werden durch Baganator hinzugefügt, nicht durch unser System
    -- Für Standard-Blizzard-Bank ohne Addons funktionieren die Icons nur über Bag-Addons
    
    -- Trotzdem versuchen wir es über die Container-Frames
    if ContainerFrameUtil_EnumerateContainerFrames then
        ContainerFrameUtil_EnumerateContainerFrames(function(frame)
            if not frame or not frame:IsShown() then return end
            
            -- Wenn das Frame EnumerateValidItems hat, nutze es
            if frame.EnumerateValidItems then
                for _, itemButton in frame:EnumerateValidItems() do
                    -- Update alle Buttons, egal welcher Bag
                    UpdateBagSlotIcon(itemButton)
                end
            end
        end)
    end
end

-- Einfache direkte Update-Funktion
local function UpdateAllBagSlots()
    -- Methode 1: Versuche ContainerFrameUtil (TWW+)
    if ContainerFrameUtil_EnumerateContainerFrames then
        ContainerFrameUtil_EnumerateContainerFrames(function(frame)
            if frame and frame.EnumerateValidItems then
                for _, itemButton in frame:EnumerateValidItems() do
                    UpdateBagSlotIcon(itemButton)
                end
            end
        end)
    end
    
    -- Methode 2: Update Bank-Slots separat
    UpdateBankSlots()
end

-- Hook für einzelne Bag-Buttons
local function HookBagButton(button)
    if not button or button.housingHooked then return end
    
    -- Hook Update-Events
    if button.UpdateTooltip then
        hooksecurefunc(button, "UpdateTooltip", function(self)
            UpdateBagSlotIcon(self)
        end)
    end
    
    button.housingHooked = true
    UpdateBagSlotIcon(button)
end

-- Hook für Inventar-Slots
local function UpdateInventorySlotIcon(slotId)
    local itemId = GetInventoryItemID("player", slotId)
    local button = _G["CharacterSlot" .. slotId]
    
    if not button then
        -- Versuche alternative Button-Namen
        local slotNames = {
            [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest",
            [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands",
            [11] = "Finger0", [12] = "Finger1", [13] = "Trinket0", [14] = "Trinket1",
            [15] = "Back", [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged", [19] = "Tabard"
        }
        if slotNames[slotId] then
            button = _G["Character" .. slotNames[slotId] .. "Slot"]
        end
    end
    
    if button then
        if itemId and IsHousingItem(itemId) then
            if not button.housingIcon then
                button.housingIcon = button:CreateTexture(nil, "OVERLAY", nil, 7)
                button.housingIcon:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\decorCost")
                button.housingIcon:SetSize(16, 16)
                button.housingIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
                button.housingIcon:SetVertexColor(1, 0.82, 0, 1)  -- Gold
                button.housingIcon:SetDrawLayer("OVERLAY", 7)
            end
            button.housingIcon:Show()
        else
            if button.housingIcon then
                button.housingIcon:Hide()
            end
        end
    end
end

-- Event-Handler
HousingItemTracker:RegisterEvent("ADDON_LOADED")
HousingItemTracker:RegisterEvent("BAG_UPDATE_DELAYED")
HousingItemTracker:RegisterEvent("UNIT_INVENTORY_CHANGED")
HousingItemTracker:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
HousingItemTracker:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
HousingItemTracker:RegisterEvent("BANKFRAME_OPENED")

-- Hook für Housing Dashboard und andere UI-Tooltips
local function SetupHousingDashboardHooks()
    -- Hook für das Housing Dashboard Catalog Entry Event
    -- Dies ist der offizielle Event-Hook für Housing Catalog Tooltips
    -- Parameter Signatur: caller (CallbackRegistry), catalogEntryFrame, tooltip
    if EventRegistry and not _G.HousingItemTrackerCatalogHooked then
        EventRegistry:RegisterCallback("HousingCatalogEntry.TooltipCreated", function(caller, catalogEntryFrame, tooltip)
            -- caller = die CallbackRegistry (ignorieren)
            -- catalogEntryFrame = der HousingCatalogEntry Frame
            -- tooltip = GameTooltip
            
            -- NUR im Housing Dashboard Catalog anzeigen, NICHT im Editor Mode
            -- Prüfe ob wir im House Editor sind
            if C_HouseEditor and C_HouseEditor.IsHouseEditorActive() then
                -- Im Editor Mode - KEINE zusätzlichen Infos anzeigen
                return
            end
            
            if catalogEntryFrame and catalogEntryFrame.entryInfo then
                -- Das entryInfo hat eine decorID für Decor-Items
                local decorID = catalogEntryFrame.entryInfo.entryID and catalogEntryFrame.entryInfo.entryID.recordID
                
                -- Debug: Zeige die decorID
                if decorID then
                    -- Temporäres Debug (kann später entfernt werden)
                    -- print("[Housing] Catalog Entry decorID:", decorID, "Name:", catalogEntryFrame.entryInfo.name)
                    
                    -- Für Decor-Items: Zeige Source-Informationen
                    if DB.decorItems and DB.decorItems[decorID] then
                        AddTooltipInfo(tooltip, decorID)
                    else
                        -- Debug: Item nicht in DB gefunden
                        -- print("[Housing] DecorID", decorID, "nicht in Datenbank gefunden")
                        
                        -- Zeige zumindest eine Basis-Info dass wir es erkannt haben
                        tooltip:AddLine(" ")
                        tooltip:AddLine("|cFF00FF00[Housing Item]|r", 1, 1, 1)
                        tooltip:AddLine("DecorID: " .. decorID, 0.6, 0.6, 0.6)
                    end
                end
            end
        end)
        _G.HousingItemTrackerCatalogHooked = true
    end
    
    -- Hook für Hyperlinks (z.B. im Chat oder anderen UIs)
    if GameTooltip and GameTooltip.SetHyperlink and not GameTooltip.housingHyperlinkHooked then
        hooksecurefunc(GameTooltip, "SetHyperlink", function(self, link)
            if link then
                local itemId = GetItemIdFromLink(link)
                if itemId then
                    -- Kleine Verzögerung damit der Tooltip zuerst gerendert wird
                    C_Timer.After(0.01, function()
                        AddTooltipInfo(self, itemId)
                    end)
                end
            end
        end)
        GameTooltip.housingHyperlinkHooked = true
    end
    
    -- Hook für ItemRefTooltip (wird für Item-Links verwendet)
    if ItemRefTooltip and ItemRefTooltip.SetHyperlink and not ItemRefTooltip.housingHyperlinkHooked then
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if link then
                local itemId = GetItemIdFromLink(link)
                if itemId then
                    C_Timer.After(0.01, function()
                        AddTooltipInfo(self, itemId)
                    end)
                end
            end
        end)
        ItemRefTooltip.housingHyperlinkHooked = true
    end
end

HousingItemTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = select(1, ...)
        
        if loadedAddon == addonName then
            -- Setup Tooltip-Hooks
            SetupTooltipHooks()
            
            -- Setup Housing Dashboard Hooks (verzögert)
            C_Timer.After(1, SetupHousingDashboardHooks)
            C_Timer.After(3, SetupHousingDashboardHooks) -- Nochmal später für sicheren Hook
            
            -- Zähle Items in der Datenbank
            local itemCount = 0
            for _ in pairs(DB.materials) do
                itemCount = itemCount + 1
            end
            
            -- Zeige Lade-Nachricht im Chat
            print("|cFF00FF00===================================|r")
            print("|cFF00FF00Housing Item Tracker|r |cFFFFFFFFv" .. HousingItemTrackerDB.version .. "|r")
            print("|cFFFFFFFFErfolgreich geladen!|r")
            print("|cFFFFFFFF" .. itemCount .. " Housing-Materialien|r in der Datenbank")
            print("|cFF00FF00===================================|r")
            
            -- Initiales Update nach kurzer Verzögerung
            C_Timer.After(1, function()
                UpdateAllBagSlots()
                for slotId = 1, 19 do
                    UpdateInventorySlotIcon(slotId)
                end
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Update alle Bag-Slots wenn sich was ändert
        -- Warte einen kurzen Moment, damit andere Addons ihre Frames aktualisieren können
        C_Timer.After(0.1, function()
            if ContainerFrameUtil_EnumerateContainerFrames then
                ContainerFrameUtil_EnumerateContainerFrames(function(frame)
                    if frame and frame:IsShown() then
                        for _, itemButton in frame:EnumerateValidItems() do
                            UpdateBagSlotIcon(itemButton)
                        end
                    end
                end)
            end
        end)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = select(1, ...)
        if unit == "player" then
            -- Update alle Inventar-Slots
            for slotId = 1, 19 do
                UpdateInventorySlotIcon(slotId)
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotId = select(1, ...)
        if slotId then
            UpdateInventorySlotIcon(slotId)
        end
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
        -- Update Bank-Icons mit mehreren Versuchen
        C_Timer.After(0.1, UpdateBankSlots)
        C_Timer.After(0.3, UpdateBankSlots)
        C_Timer.After(0.5, UpdateBankSlots)
    end
end)

-- Hook für Container-Frames (modernes System wie Pawn)
local function HookContainerFrame(frame)
    if not frame or frame.housingHooked then return end
    
    if frame.UpdateItems then
        hooksecurefunc(frame, "UpdateItems", function(self)
            if self.EnumerateValidItems then
                for _, itemButton in self:EnumerateValidItems() do
                    UpdateBagSlotIcon(itemButton)
                end
            end
        end)
    end
    
    -- Zusätzlicher Hook für Show-Event (wichtig für Bank)
    if frame.SetScript then
        frame:HookScript("OnShow", function(self)
            C_Timer.After(0.1, function()
                if self:IsShown() and self.EnumerateValidItems then
                    for _, itemButton in self:EnumerateValidItems() do
                        UpdateBagSlotIcon(itemButton)
                    end
                end
            end)
        end)
    end
    
    frame.housingHooked = true
end

-- Hook alle Container-Frames und Combined Bags
C_Timer.After(1, function()
    -- Hook Combined Bags (TWW+)
    if ContainerFrameCombinedBags then
        HookContainerFrame(ContainerFrameCombinedBags)
    end
    
    -- Hook Reagent Bag (ContainerFrame6)
    if _G["ContainerFrame6"] then
        HookContainerFrame(_G["ContainerFrame6"])
    end
    
    -- Hook Bank Frames (ContainerFrame7-13 sind Bank-Slots)
    -- ContainerFrame7 = Bank Hauptfach, ContainerFrame8-13 = Bank Bag Slots 1-6
    for i = 7, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            HookContainerFrame(frame)
        end
    end
    
    -- Hook Combined Bank Frame (TWW+)
    if BankFrame then
        HookContainerFrame(BankFrame)
    end
    
    -- Hook einzelne Bag-Frames (ContainerFrame1-5)
    for i = 1, 5 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            HookContainerFrame(frame)
        end
    end
    
    -- Hook auch über ContainerFrameUtil falls verfügbar
    if ContainerFrameUtil_EnumerateContainerFrames then
        ContainerFrameUtil_EnumerateContainerFrames(HookContainerFrame)
    end
    
    -- Initiales Update
    UpdateAllBagSlots()
end)


-- Slash-Command zum manuellen Update
SLASH_HOUSINGITEMTRACKER1 = "/hit"
SLASH_HOUSINGITEMTRACKER2 = "/housingitemtracker"
SlashCmdList["HOUSINGITEMTRACKER"] = function(msg)
    if msg == "update" or msg == "" then
        print("|cFF00FF00Housing Item Tracker:|r Aktualisiere Icons...")
        UpdateAllBagSlots()
        for slotId = 1, 19 do
            UpdateInventorySlotIcon(slotId)
        end
    elseif msg == "debug" then
        print("|cFF00FF00Housing Item Tracker Debug:|r")
        print("ContainerFrameUtil_EnumerateContainerFrames: " .. tostring(ContainerFrameUtil_EnumerateContainerFrames ~= nil))
        print("DB.materials hat Einträge: " .. tostring(next(DB.materials) ~= nil))
        
        -- Teste ein bekanntes Item
        local testItemId = 2325 -- Erstes Item in der DB
        print("Test Item 2325 ist Housing Item: " .. tostring(IsHousingItem(testItemId)))
    elseif msg == "test" then
        print("|cFF00FF00Housing Item Tracker:|r Teste Icon-System...")
        UpdateAllBagSlots()
        print("Icons aktualisiert!")
    elseif msg == "bank" then
        print("|cFF00FF00Housing Item Tracker:|r Teste Bank-Buttons...")
        
        -- Teste Bank Hauptfach
        for slotID = 1, 28 do
            local button = _G["BankFrameItem" .. slotID]
            if button then
                print("BankFrameItem" .. slotID .. " gefunden")
                local itemId = C_Container.GetContainerItemID(-1, slotID)
                if itemId then
                    print("  Item: " .. itemId .. " - Housing: " .. tostring(IsHousingItem(itemId)))
                end
            else
                print("BankFrameItem" .. slotID .. " NICHT gefunden")
            end
        end
        
        -- Teste Bank Bags
        for bagID = 5, 11 do
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            if numSlots and numSlots > 0 then
                print("Bank Bag " .. bagID .. " hat " .. numSlots .. " Slots")
                for slotID = 1, math.min(5, numSlots) do
                    local buttonName = "ContainerFrame" .. (bagID + 2) .. "Item" .. slotID
                    local button = _G[buttonName]
                    if button then
                        print("  " .. buttonName .. " gefunden")
                    else
                        print("  " .. buttonName .. " NICHT gefunden")
                    end
                end
            end
        end
        
        UpdateBankSlots()
        print("Bank-Icons aktualisiert!")
    else
        print("|cFF00FF00Housing Item Tracker Befehle:|r")
        print("/hit update - Icons aktualisieren")
        print("/hit debug - Debug-Informationen anzeigen")
        print("/hit test - Test-Icon auf erstem Bag-Slot erstellen")
        print("/hit bank - Bank-Buttons testen und Icons aktualisieren")
    end
end

