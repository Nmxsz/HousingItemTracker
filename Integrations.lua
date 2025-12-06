-- Housing Item Tracker - Integrations for Bag Addons
-- Unterstützung für Baganator, Bagnon, AdiBags, etc.

local addonName = "HousingItemTracker"

-- Warte bis HousingItemTracker geladen ist
local function IsHousingItem(itemId)
    if not HousingItemTrackerDB or not HousingItemTrackerDB.items then return false end
    return HousingItemTrackerDB.items.materials[itemId] == true
end

------------------------------------------------------------
-- Baganator Integration
------------------------------------------------------------

local function SetupBaganatorIntegration()
    if not Baganator or not Baganator.API then
        return
    end
    
    -- Registriere Corner Widget (Icon in der Ecke)
    Baganator.API.RegisterCornerWidget(
        "Housing Item Tracker",  -- Name
        "housingitemtracker",    -- ID
        function(_, details)     -- Prüfungs-Funktion
            if not details or not details.itemLink then return false end
            local itemId = tonumber(details.itemLink:match("item:(%d+)"))
            return itemId and IsHousingItem(itemId)
        end,
        function(itemButton)     -- Widget-Erstellungs-Funktion
            local Arrow = itemButton:CreateTexture(nil, "OVERLAY")
            Arrow:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\decorCost")
            Arrow:SetSize(16, 16)
            Arrow:SetVertexColor(1, 0.82, 0, 1)  -- Gold
            return Arrow
        end,
        {corner = "top_right", priority = 2}  -- Position und Priorität
    )
    
    -- Registriere als Upgrade-Plugin (für Suche/Filter)
    Baganator.API.RegisterUpgradePlugin(
        "Housing Item Tracker",
        "housingitemtracker",
        function(itemLink)
            if not itemLink then return false end
            local itemId = tonumber(itemLink:match("item:(%d+)"))
            return itemId and IsHousingItem(itemId)
        end
    )
end

------------------------------------------------------------
-- Bagnon Integration
------------------------------------------------------------

local function SetupBagnonIntegration()
    if not Bagnon then
        return
    end
    
    -- Hook Bagnon's Item Update
    hooksecurefunc(Bagnon.Item, "Update", function(self)
        if not self.hasItem then return end
        
        local itemId = C_Container.GetContainerItemID(self:GetBag(), self:GetID())
        if itemId and IsHousingItem(itemId) then
            if not self.housingIcon then
                self.housingIcon = self:CreateTexture(nil, "OVERLAY")
                self.housingIcon:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\decorCost")
                self.housingIcon:SetSize(16, 16)
                self.housingIcon:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
                self.housingIcon:SetVertexColor(1, 0.82, 0, 1)  -- Gold
                self.housingIcon:SetDrawLayer("OVERLAY", 7)
            end
            self.housingIcon:Show()
        else
            if self.housingIcon then
                self.housingIcon:Hide()
            end
        end
    end)
end

------------------------------------------------------------
-- AdiBags Integration
------------------------------------------------------------

local function SetupAdiBagsIntegration()
    if not AdiBags then
        return
    end
    
    -- Registriere einen Filter für Housing Items
    local filter = AdiBags:RegisterFilter("Housing Items", 90, "ABEvent-1.0")
    filter.uiName = "Housing Items"
    filter.uiDesc = "Zeigt Housing-Crafting Materialien an"
    
    function filter:OnInitialize()
        self.db = AdiBags.db:RegisterNamespace("HousingItemTracker", {
            profile = { enable = true }
        })
    end
    
    function filter:Update()
        self:SendMessage("AdiBags_FiltersChanged")
    end
    
    function filter:OnEnable()
        AdiBags:UpdateFilters()
    end
    
    function filter:OnDisable()
        AdiBags:UpdateFilters()
    end
    
    function filter:Filter(slotData)
        if not self.db.profile.enable then return end
        if not slotData.itemId then return end
        
        if IsHousingItem(slotData.itemId) then
            return "Housing Materials"
        end
    end
    
    -- Hook für Icon-Anzeige
    hooksecurefunc(AdiBags, "UpdateButton", function(self, button)
        if not button then return end
        
        local bagId = button:GetParent():GetID()
        local slotId = button:GetID()
        local itemId = C_Container.GetContainerItemID(bagId, slotId)
        
        if itemId and IsHousingItem(itemId) then
            if not button.housingIcon then
                button.housingIcon = button:CreateTexture(nil, "OVERLAY")
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
    end)
end

------------------------------------------------------------
-- ArkInventory Integration
------------------------------------------------------------

local function SetupArkInventoryIntegration()
    if not ArkInventory or not ArkInventory.API then
        return
    end
    
    -- Verwende die offizielle ArkInventory API
    hooksecurefunc(ArkInventory.API, "ItemFrameUpdated", function(frame, loc_id, bag_id, slot_id)
        if not frame or not frame.ARK_Data then return end
        
        -- Hole die Item-Daten über die offizielle API
        local itemData = ArkInventory.API.ItemFrameItemTableGet(frame)
        if not itemData then return end
        
        local itemId = nil
        
        -- itemData.h kann entweder eine itemID (number) oder ein Hyperlink (string) sein
        if itemData.h then
            if type(itemData.h) == "number" then
                itemId = itemData.h
            elseif type(itemData.h) == "string" then
                -- Extrahiere die itemID aus dem Hyperlink
                itemId = tonumber(itemData.h:match("item:(%d+)"))
            end
        end
        
        -- Überprüfe, ob es ein Housing-Item ist
        if itemId and IsHousingItem(itemId) then
            -- Erstelle das Icon nur einmal
            if not frame.housingIcon then
                frame.housingIcon = frame:CreateTexture(nil, "OVERLAY")
                frame.housingIcon:SetTexture("Interface\\AddOns\\HousingItemTracker\\textures\\decorCost")
                frame.housingIcon:SetSize(16, 16)
                frame.housingIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
                frame.housingIcon:SetVertexColor(1, 0.82, 0, 1)  -- Gold
                frame.housingIcon:SetDrawLayer("OVERLAY", 7)
            end
            frame.housingIcon:Show()
        else
            -- Verstecke das Icon, wenn es kein Housing-Item ist
            if frame.housingIcon then
                frame.housingIcon:Hide()
            end
        end
    end)
end

------------------------------------------------------------
-- Initialisierung
------------------------------------------------------------

local IntegrationFrame = CreateFrame("Frame")
IntegrationFrame:RegisterEvent("ADDON_LOADED")
IntegrationFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        -- Warte einen Moment, damit andere Addons laden können
        C_Timer.After(2, function()
            -- Versuche alle bekannten Bag-Addons zu integrieren
            if Baganator then
                pcall(SetupBaganatorIntegration)
            end
            
            if Bagnon then
                pcall(SetupBagnonIntegration)
            end
            
            if AdiBags then
                pcall(SetupAdiBagsIntegration)
            end
            
            if ArkInventory then
                pcall(SetupArkInventoryIntegration)
            end
        end)
    end
end)

