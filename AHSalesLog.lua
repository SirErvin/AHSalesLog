-- AHSalesLog.lua
-- Protokolliert Auktionshaus-Verkäufe
-- Interface: TBC Classic Anniversary

-- ============================================================
-- Konstanten & Hilfsvariablen
-- ============================================================

local ADDON_NAME = "AHSalesLog"
local ADDON_VERSION = "1.2.0"
local MAX_ENTRIES = 200

local COL_TS    = 80
local COL_ITEM  = 185
local COL_PRICE = 95

local FRAME_WIDTH  = 400
local FRAME_HEIGHT = 345
local ROW_HEIGHT   = 18
local HEADER_H     = 16
local TAB_H        = 22
local PAD          = 8

local AHSalesLogFrame = nil
local scrollChild     = nil
local rowFrames       = {}
local unseenCount     = 0
local minimapBtn      = nil
local activeTab       = "sold"   -- "sold" oder "listed"
local tabBtnSold      = nil
local tabBtnListed    = nil

-- Rate-Limiter für Chat-Filter (verhindert Doppeleinträge bei mehreren Chatframes)
local lastFilterMsg  = nil
local lastFilterTime = 0

-- ============================================================
-- SavedVariables initialisieren
-- ============================================================

local function InitDB()
    if not AHSalesLogDB then AHSalesLogDB = {} end
    if not AHSalesLogDB.entries          then AHSalesLogDB.entries          = {} end
    if not AHSalesLogDB.framePos         then AHSalesLogDB.framePos         = { point="CENTER", x=0, y=0 } end
    if not AHSalesLogDB.minimapAngle     then AHSalesLogDB.minimapAngle     = 225 end
    if not AHSalesLogDB.seenMailKeys     then AHSalesLogDB.seenMailKeys     = {} end
    if not AHSalesLogDB.pendingAuctions  then AHSalesLogDB.pendingAuctions  = {} end

    -- Alte pending-Einträge entfernen (älter als 48h)
    local now = time()
    local pending = AHSalesLogDB.pendingAuctions
    for i = #pending, 1, -1 do
        if now - (pending[i].posted or 0) > 172800 then
            table.remove(pending, i)
        end
    end
end

local function GetTimestamp()
    return date("%d.%m. %H:%M")
end

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function FormatMoney(copper)
    if not copper or copper == 0 then return "" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

-- Itemlinks und Farbcodes entfernen
local function StripLinks(s)
    return s:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|h%[(.-)%]|h", "%1")
             :gsub("|H[^|]+|h", "")
             :gsub("|h", "")
             :gsub("|r", "")
             :match("^%s*(.-)%s*$")
end

-- ============================================================
-- Minimap-Badge
-- ============================================================

local function UpdateMinimapBadge()
    if not minimapBtn then return end
    if unseenCount > 0 then
        minimapBtn.badge:Show()
        minimapBtn.badgeText:SetText(unseenCount > 9 and "9+" or tostring(unseenCount))
    else
        minimapBtn.badge:Hide()
    end
end

-- ============================================================
-- Tab-Styling
-- ============================================================

local function UpdateTabStyle()
    if not tabBtnSold or not tabBtnListed then return end
    if activeTab == "sold" then
        tabBtnSold:SetNormalFontObject("GameFontNormal")
        tabBtnListed:SetNormalFontObject("GameFontNormalSmall")
    else
        tabBtnSold:SetNormalFontObject("GameFontNormalSmall")
        tabBtnListed:SetNormalFontObject("GameFontNormal")
    end
end

-- ============================================================
-- Eintrag hinzufügen / Preis nachträglich setzen
-- ============================================================

local function AddEntry(item, price)
    table.insert(AHSalesLogDB.entries, 1, {
        time  = GetTimestamp(),
        item  = item,
        price = price or "",
    })
    while #AHSalesLogDB.entries > MAX_ENTRIES do
        table.remove(AHSalesLogDB.entries)
    end

    if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
        AHSalesLog_RefreshList()
    else
        unseenCount = unseenCount + 1
        UpdateMinimapBadge()
    end
end

-- Sucht den neuesten Eintrag ohne Preis für das gegebene Item und setzt den Preis.
local function EnrichEntryPrice(item, priceStr)
    for _, entry in ipairs(AHSalesLogDB.entries) do
        if entry.price == "" and entry.item == item then
            entry.price = priceStr
            return true
        end
    end
    return false
end

-- ============================================================
-- Pending-Auktionen: Preis beim Einstellen merken
-- ============================================================

-- Sucht in der pending-Liste nach dem Item und gibt den Buyout-Preis zurück.
-- Entfernt den Eintrag bei Treffer (FIFO).
local function FindPendingPrice(itemName)
    local pending = AHSalesLogDB.pendingAuctions
    for i, entry in ipairs(pending) do
        if entry.item == itemName then
            local priceStr = entry.priceStr or FormatMoney(entry.buyout)
            table.remove(pending, i)
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
                AHSalesLog_RefreshList()
            end
            return priceStr
        end
    end
    return nil
end

local function HookPostAuction()
    hooksecurefunc("PostAuction", function(startPrice, buyoutPrice, duration)
        local name, _, count = GetAuctionSellItemInfo()
        if name then
            local price = buyoutPrice and buyoutPrice > 0 and buyoutPrice or startPrice
            table.insert(AHSalesLogDB.pendingAuctions, {
                item     = name,
                buyout   = price,
                priceStr = FormatMoney(price),
                count    = count or 1,
                posted   = time(),
                time     = GetTimestamp(),
            })
            -- Limit auf 200
            while #AHSalesLogDB.pendingAuctions > 200 do
                table.remove(AHSalesLogDB.pendingAuctions, 1)
            end
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
                AHSalesLog_RefreshList()
            end
        end
    end)
end

-- ============================================================
-- Chat-Filter: sofortige Erkennung mit Itemname
-- ============================================================

-- UTF-8 Hinweis: "Käufer" / "für" enthalten Umlaute (2 Bytes in UTF-8).
-- Lua-Pattern "." matcht nur 1 Byte. Daher suchen wir nach "gefunden: ".

local function AHSalesLog_ChatFilter(_, _, msg)
    local item = msg:match("gefunden: (.-)%s*$")
                 or msg:match("found for your auction of (.-)%s*$")

    if item and item ~= "" then
        local now = GetTime()
        if msg ~= lastFilterMsg or (now - lastFilterTime) > 0.05 then
            lastFilterMsg  = msg
            lastFilterTime = now
            local cleanName = StripLinks(item)
            local priceStr  = FindPendingPrice(cleanName)
            AddEntry(cleanName, priceStr)
        end
    end

    return false
end

-- ============================================================
-- Postfach: Preise nachträglich anreichern
-- ============================================================

local AH_SENDERS = { "Auktionshaus", "Auction House" }

local function IsAHSender(sender)
    if not sender then return false end
    for _, name in ipairs(AH_SENDERS) do
        if sender:find(name, 1, true) then return true end
    end
    return false
end

local function ScanMailbox()
    local numItems = GetInboxNumItems()
    if numItems == 0 then return end

    local seenKeys  = AHSalesLogDB.seenMailKeys
    local refreshUI = false

    for i = 1, numItems do
        local _, _, sender, subject, money = GetInboxHeaderInfo(i)

        if IsAHSender(sender) and money and money > 0 then
            local key = (subject or "") .. "|" .. tostring(money)

            if not seenKeys[key] then
                seenKeys[key] = true

                local item = nil
                if subject then
                    item = subject:match("%[(.-)%]") or StripLinks(subject)
                end

                local priceStr = FormatMoney(money)

                if item and item ~= "" then
                    if EnrichEntryPrice(item, priceStr) then
                        refreshUI = true
                    end
                end
            end
        end
    end

    -- seenMailKeys auf max. 500 Einträge begrenzen
    local count = 0
    for _ in pairs(seenKeys) do count = count + 1 end
    if count > 500 then
        AHSalesLogDB.seenMailKeys = {}
        for i = 1, numItems do
            local _, _, sender, subject, money = GetInboxHeaderInfo(i)
            if IsAHSender(sender) and money and money > 0 then
                local key = (subject or "") .. "|" .. tostring(money)
                AHSalesLogDB.seenMailKeys[key] = true
            end
        end
    end

    if refreshUI and AHSalesLogFrame and AHSalesLogFrame:IsShown() then
        AHSalesLog_RefreshList()
    end
end

-- ============================================================
-- UI: Hauptfenster
-- ============================================================

local function CreateMainFrame()
    local f = CreateFrame("Frame", "AHSalesLogFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:Hide()

    f.TitleText:SetText("AH Sales Log  v" .. ADDON_VERSION)

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        AHSalesLogDB.framePos = { point = point, x = x, y = y }
    end)

    -- Tab-Buttons
    local tabTop = -28

    local btnSold = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnSold:SetSize(120, TAB_H)
    btnSold:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, tabTop)
    btnSold:SetText("Verkauft")
    btnSold:SetScript("OnClick", function()
        activeTab = "sold"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnSold = btnSold

    local btnListed = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnListed:SetSize(120, TAB_H)
    btnListed:SetPoint("LEFT", btnSold, "RIGHT", 4, 0)
    btnListed:SetText("Eingestellt")
    btnListed:SetScript("OnClick", function()
        activeTab = "listed"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnListed = btnListed

    UpdateTabStyle()

    -- Spaltenüberschriften
    local headerTop = tabTop - TAB_H - 2

    local headerBg = f:CreateTexture(nil, "BACKGROUND")
    headerBg:SetColorTexture(0, 0, 0, 0.5)
    headerBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD,       headerTop)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD+20), headerTop)
    headerBg:SetHeight(HEADER_H)

    local function MakeHeader(text, leftOffset)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", headerBg, "LEFT", leftOffset, 0)
        lbl:SetTextColor(0.9, 0.85, 0.3)
        lbl:SetText(text)
    end
    MakeHeader("Zeit",  2)
    MakeHeader("Item",  2 + COL_TS + 4)
    MakeHeader("Preis", 2 + COL_TS + 4 + COL_ITEM + 4)

    -- ScrollFrame
    local sf = CreateFrame("ScrollFrame", "AHSalesLogScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",  PAD,       headerTop - HEADER_H)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 30)

    local sc = CreateFrame("Frame", "AHSalesLogScrollChild", sf)
    sc:SetWidth(FRAME_WIDTH - PAD - (PAD + 20))
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    scrollChild = sc

    -- "Leeren"-Button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 6)
    clearBtn:SetText("Leeren")
    clearBtn:SetScript("OnClick", function()
        if activeTab == "sold" then
            AHSalesLogDB.entries = {}
        else
            AHSalesLogDB.pendingAuctions = {}
        end
        AHSalesLog_RefreshList()
    end)

    local countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 10)
    countLabel:SetTextColor(0.6, 0.6, 0.6)
    f.countLabel = countLabel

    AHSalesLogFrame = f
end

-- ============================================================
-- UI: Liste neu aufbauen
-- ============================================================

function AHSalesLog_RefreshList()
    local data
    if activeTab == "sold" then
        data = AHSalesLogDB.entries
    else
        data = AHSalesLogDB.pendingAuctions
    end

    local count = #data

    for _, row in ipairs(rowFrames) do row:Hide() end

    scrollChild:SetHeight(math.max(count * ROW_HEIGHT + 4, 1))

    for i, entry in ipairs(data) do
        local row = rowFrames[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)
            row:EnableMouse(true)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.ts = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.ts:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.ts:SetWidth(COL_TS)
            row.ts:SetJustifyH("LEFT")

            row.item = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.item:SetPoint("LEFT", row.ts, "RIGHT", 4, 0)
            row.item:SetWidth(COL_ITEM)
            row.item:SetJustifyH("LEFT")

            row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.price:SetPoint("LEFT", row.item, "RIGHT", 4, 0)
            row.price:SetWidth(COL_PRICE)
            row.price:SetJustifyH("LEFT")

            row:SetScript("OnEnter", function(self)
                if self.fullItem and self.fullItem ~= "" then
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                    GameTooltip:SetText(self.fullItem, 1, 1, 1)
                    if self.fullPrice ~= "" then
                        GameTooltip:AddLine("Preis: " .. self.fullPrice, 0.4, 1, 0.4)
                    end
                    GameTooltip:AddLine(self.fullTime, 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            rowFrames[i] = row
        end

        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, -(i-1) * ROW_HEIGHT - 2)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i-1) * ROW_HEIGHT - 2)
        row:Show()

        if i % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.05)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        -- Daten je nach Tab auslesen
        local displayTime  = entry.time or ""
        local displayItem  = entry.item or ""
        local displayPrice = entry.priceStr or entry.price or ""

        row.fullItem  = displayItem
        row.fullPrice = displayPrice
        row.fullTime  = displayTime

        row.ts:SetText(displayTime)
        row.ts:SetTextColor(0.6, 0.6, 0.6)
        row.item:SetText(displayItem)
        row.item:SetTextColor(1, 0.82, 0)
        if displayPrice ~= "" then
            row.price:SetText(displayPrice)
            if activeTab == "sold" then
                row.price:SetTextColor(0.4, 1, 0.4)
            else
                row.price:SetTextColor(1, 0.82, 0)
            end
        else
            row.price:SetText("--")
            row.price:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    if AHSalesLogFrame and AHSalesLogFrame.countLabel then
        AHSalesLogFrame.countLabel:SetText(count .. " Eintr.")
    end
end

-- ============================================================
-- Minimap-Button
-- ============================================================

local function SetMinimapPos(btn)
    local rad = math.rad(AHSalesLogDB.minimapAngle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "AHSalesLogMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bg:SetSize(56, 56)
    bg:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local badge = CreateFrame("Frame", nil, btn)
    badge:SetSize(14, 14)
    badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    badge:SetFrameLevel(btn:GetFrameLevel() + 2)

    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetColorTexture(0.8, 0.1, 0.1, 1)
    badgeBg:SetAllPoints()

    local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("CENTER")
    badgeText:SetTextColor(1, 1, 1)

    btn.badge     = badge
    btn.badgeText = badgeText
    badge:Hide()

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("AH Log", 1, 1, 1)
        GameTooltip:AddLine("Klick: Fenster ein-/ausblenden", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Position ändern",          0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function()
        if AHSalesLogFrame:IsShown() then
            AHSalesLogFrame:Hide()
        else
            unseenCount = 0
            UpdateMinimapBadge()
            AHSalesLog_RefreshList()
            AHSalesLogFrame:Show()
            AHSalesLogFrame:Raise()
        end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(s)
            if not s.dragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            AHSalesLogDB.minimapAngle = math.deg(math.atan2(cy/scale - my, cx/scale - mx))
            SetMinimapPos(s)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    minimapBtn = btn
    SetMinimapPos(btn)
end

-- ============================================================
-- Toggle
-- ============================================================

local function ToggleFrame()
    if AHSalesLogFrame:IsShown() then
        AHSalesLogFrame:Hide()
    else
        unseenCount = 0
        UpdateMinimapBadge()
        AHSalesLog_RefreshList()
        AHSalesLogFrame:Show()
        AHSalesLogFrame:Raise()
    end
end

-- ============================================================
-- Addon-Initialisierung
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        InitDB()
        CreateMainFrame()
        CreateMinimapButton()

        local pos = AHSalesLogDB.framePos
        AHSalesLogFrame:ClearAllPoints()
        AHSalesLogFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", AHSalesLog_ChatFilter)

        HookPostAuction()

        SLASH_AHSALESLOG1 = "/ahlog"
        SLASH_AHSALESLOG2 = "/ahsaleslog"
        SlashCmdList["AHSALESLOG"] = ToggleFrame

        SLASH_AHSALESLOGTEST1 = "/ahlogtest"
        SlashCmdList["AHSALESLOGTEST"] = function()
            -- Simuliere: Item einstellen + verkaufen
            table.insert(AHSalesLogDB.pendingAuctions, 1, {
                item     = "Schattenpanzerhelm",
                buyout   = 53210,
                priceStr = "5g 32s 10c",
                count    = 1,
                posted   = time(),
                time     = GetTimestamp(),
            })
            AddEntry("Schattenpanzerhelm", FindPendingPrice("Schattenpanzerhelm"))
            print("|cff00ff00AHSalesLog:|r Testeintrag hinzugefügt (Eingestellt -> Verkauft).")
        end

        SLASH_AHSALESLOGTEST2 = "/ahlogtest2"
        SlashCmdList["AHSALESLOGTEST2"] = function()
            -- Simuliere: nur Item einstellen (bleibt im "Eingestellt"-Tab)
            table.insert(AHSalesLogDB.pendingAuctions, 1, {
                item     = "Tigeraugenfell",
                buyout   = 120000,
                priceStr = "12g",
                count    = 1,
                posted   = time(),
                time     = GetTimestamp(),
            })
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
                AHSalesLog_RefreshList()
            end
            print("|cff00ff00AHSalesLog:|r Testeintrag im 'Eingestellt'-Tab hinzugefügt.")
        end

        print("|cff00ff00AHSalesLog|r geladen.  /ahlog  /ahlogtest  /ahlogtest2")

    elseif event == "MAIL_INBOX_UPDATE" then
        ScanMailbox()
    end
end)
