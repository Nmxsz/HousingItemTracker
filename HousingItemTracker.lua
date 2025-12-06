-- Housing Item Tracker
-- Markiert Items, die für Housing-Crafting benötigt werden

local addonName = "HousingItemTracker"
local HousingItemTracker = CreateFrame("Frame")

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

-- Prüft ob ein Item für Housing benötigt wird
local function IsHousingItem(itemId)
    if not itemId then return false end
    return DB.materials[itemId] == true
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
    
    if isMaterial or isDecor then
        tooltip:AddLine(" ") -- Leerzeile
        tooltip:AddLine("|cFF00FF00[Housing]|r", 1, 1, 1)
        
        if isMaterial then
            tooltip:AddLine("Benötigt für Housing-Crafting", 0.8, 0.8, 0.8)
        end
        
        if isDecor then
            tooltip:AddLine("Housing Decor-Item", 0.8, 0.8, 0.8)
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
    local _, itemLink = tooltip:GetItem()
    if itemLink then
        local itemId = GetItemIdFromLink(itemLink)
        if itemId then
            AddTooltipInfo(tooltip, itemId)
        end
    end
end

-- Tooltip-Hook Setup (kompatibel mit modernem WoW)
local function SetupTooltipHooks()
    -- Verwende TooltipDataProcessor für moderne WoW-Versionen
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip then
                OnTooltipSetItem(tooltip)
            end
        end)
    else
        -- Fallback für ältere Versionen
        GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
end

-- Hook für Bag-Slots (Icon-Markierung) - Vereinfachtes System mit eigener Texture
local function UpdateBagSlotIcon(button)
    if not button then return end
    
    local bagID = button.GetBagID and button:GetBagID()
    local slotID = button.GetID and button:GetID()
    
    if not bagID or not slotID then return end
    
    local itemId = C_Container.GetContainerItemID(bagID, slotID)
    
    if itemId and IsHousingItem(itemId) then
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

HousingItemTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = select(1, ...)
        
        if loadedAddon == addonName then
            -- Setup Tooltip-Hooks
            SetupTooltipHooks()
            
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

