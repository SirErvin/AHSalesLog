-- AHSalesLog.lua
-- Protokolliert Auktionshaus-Verkäufe
-- Interface: TBC Classic Anniversary

-- ============================================================
-- Konstanten & Hilfsvariablen
-- ============================================================

local ADDON_NAME = "AHSalesLog"
local ADDON_VERSION = "1.8.0"
local MAX_ENTRIES = 200
local MAIL_DELAY = 3600  -- 1 Stunde bis Mail ankommt

local COL_TS    = 70
local COL_ITEM  = 150
local COL_PRICE = 80
local COL_TIMER = 55

local FRAME_WIDTH  = 460
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

local function FormatTimer(seconds)
    if seconds <= 0 then return "Bereit" end
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
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

local function AddEntry(item, price, buyoutCopper, itemCount)
    table.insert(AHSalesLogDB.entries, 1, {
        time   = GetTimestamp(),
        item   = item,
        price  = price or "",
        buyout = buyoutCopper or 0,
        soldAt = time(),
        count  = itemCount or 1,
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

-- Sucht in der pending-Liste nach dem Item und gibt Preis-String + Copper zurück.
-- Entfernt den Eintrag bei Treffer (FIFO).
local function FindPendingPrice(itemName)
    local pending = AHSalesLogDB.pendingAuctions
    for i, entry in ipairs(pending) do
        if entry.item == itemName then
            local priceStr = entry.priceStr or FormatMoney(entry.buyout)
            local copper   = entry.buyout or 0
            local count    = entry.count or 1
            table.remove(pending, i)
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
                AHSalesLog_RefreshList()
            end
            return priceStr, copper, count
        end
    end
    return nil, 0
end

-- Slot-Monitor: Erfasst Item-Info und Buyout-Preis wenn eine Auktion erstellt wird.
local pendingSellName  = nil
local pendingSellCount = nil
local pendingSellBuyout = 0
local ahIsOpen = false

local function AddPendingAuction(itemName, itemCount, buyoutPrice)
    if not itemName then return end
    table.insert(AHSalesLogDB.pendingAuctions, {
        item     = itemName,
        buyout   = buyoutPrice,
        priceStr = FormatMoney(buyoutPrice),
        count    = itemCount or 1,
        posted   = time(),
        time     = GetTimestamp(),
    })
    while #AHSalesLogDB.pendingAuctions > 200 do
        table.remove(AHSalesLogDB.pendingAuctions, 1)
    end
    if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
        AHSalesLog_RefreshList()
    end
end

-- Liest den aktuellen Buyout-Preis aus dem AH-Eingabefeld
local function ReadBuyoutFromUI()
    if BuyoutPrice and MoneyInputFrame_GetCopper then
        return MoneyInputFrame_GetCopper(BuyoutPrice) or 0
    end
    return 0
end

-- Wird bei jedem NEW_AUCTION_UPDATE aufgerufen
local function OnAuctionSlotChanged()
    if not GetAuctionSellItemInfo then return end
    local name, _, count = GetAuctionSellItemInfo()

    if name then
        pendingSellName  = name
        pendingSellCount = count
    elseif pendingSellName then
        local cursorType = GetCursorInfo()
        if cursorType ~= "item" then
            -- Auctionator handled dieses Posting bereits → Slot-Monitor überspringen
            if (GetTime() - lastAuctionatorPostTime) > 2.0 then
                local buyout = ReadBuyoutFromUI()
                if buyout == 0 then buyout = pendingSellBuyout end
                AddPendingAuction(pendingSellName, pendingSellCount, buyout)
            end
        end
        pendingSellName  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0
    end
end

-- Polling: speichert den Buyout-Preis regelmäßig solange ein Item im Slot liegt
local pollFrame = CreateFrame("Frame")
pollFrame:Hide()
local pollElapsed = 0
pollFrame:SetScript("OnUpdate", function(self, elapsed)
    pollElapsed = pollElapsed + elapsed
    if pollElapsed < 0.2 then return end
    pollElapsed = 0
    if not ahIsOpen or not pendingSellName then return end
    local buyout = ReadBuyoutFromUI()
    if buyout > 0 then
        pendingSellBuyout = buyout
    end
end)

-- ============================================================
-- Auctionator-Kompatibilität
-- ============================================================

local lastAuctionatorPostTime = 0

local function TryRegisterAuctionator()
    if not Auctionator or not Auctionator.EventBus or not Auctionator.Selling or not Auctionator.Selling.Events then
        return false
    end

    local listener = {}
    function listener:ReceiveEvent(eventName, details)
        if eventName == Auctionator.Selling.Events.PostSuccessful then
            local itemLink = details.itemInfo and details.itemInfo.itemLink or nil
            if not itemLink then return end
            local itemName = StripLinks(itemLink)
            if not itemName or itemName == "" then return end

            local numStacks = details.numStacksReached or details.numStacks or 1
            local stackSize = details.stackSize or 1
            local buyout    = details.buyoutPrice or 0

            for s = 1, numStacks do
                AddPendingAuction(itemName, stackSize, buyout)
            end

            lastAuctionatorPostTime = GetTime()
        end
    end

    Auctionator.EventBus:Register(listener, { Auctionator.Selling.Events.PostSuccessful })
    return true
end

-- ============================================================
-- Chat-Filter: sofortige Erkennung mit Itemname
-- ============================================================

local function AHSalesLog_ChatFilter(_, _, msg)
    local item = msg:match("gefunden: (.-)%s*$")
                 or msg:match("found for your auction of (.-)%s*$")

    if item and item ~= "" then
        local now = GetTime()
        if msg ~= lastFilterMsg or (now - lastFilterTime) > 0.05 then
            lastFilterMsg  = msg
            lastFilterTime = now
            local cleanName = StripLinks(item)
            local priceStr, copper, count = FindPendingPrice(cleanName)
            AddEntry(cleanName, priceStr, copper, count)
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
        local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(i)

        if IsAHSender(sender) and money and money > 0 then
            local dayKey = math.floor((daysLeft or 0) * 100)
            local key = (subject or "") .. "|" .. tostring(money) .. "|" .. tostring(dayKey)

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
            local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(i)
            if IsAHSender(sender) and money and money > 0 then
                local dayKey = math.floor((daysLeft or 0) * 100)
                local key = (subject or "") .. "|" .. tostring(money) .. "|" .. tostring(dayKey)
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
        return lbl
    end
    MakeHeader("Zeit",  2)
    MakeHeader("Item",  2 + COL_TS + 4)
    MakeHeader("Preis", 2 + COL_TS + 4 + COL_ITEM + 4)
    f.headerTimer = MakeHeader("Post", 2 + COL_TS + 4 + COL_ITEM + 4 + COL_PRICE + 4)

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

    -- Summe-Label (links neben Count)
    local sumLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sumLabel:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    sumLabel:SetTextColor(0.4, 1, 0.4)
    f.sumLabel = sumLabel

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
    local isSold = (activeTab == "sold")

    -- Timer-Header nur im Verkauft-Tab zeigen
    if AHSalesLogFrame and AHSalesLogFrame.headerTimer then
        if isSold then
            AHSalesLogFrame.headerTimer:Show()
        else
            AHSalesLogFrame.headerTimer:Hide()
        end
    end

    for _, row in ipairs(rowFrames) do row:Hide() end

    scrollChild:SetHeight(math.max(count * ROW_HEIGHT + 4, 1))

    local now = time()
    local totalCopper = 0

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

            row.timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.timer:SetPoint("LEFT", row.price, "RIGHT", 4, 0)
            row.timer:SetWidth(COL_TIMER)
            row.timer:SetJustifyH("CENTER")

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

        local displayTime  = entry.time or ""
        local displayItem  = entry.item or ""
        local entryCount   = entry.count or 1
        if entryCount > 1 then
            displayItem = displayItem .. " x" .. entryCount
        end
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
            if isSold then
                row.price:SetTextColor(0.4, 1, 0.4)
            else
                row.price:SetTextColor(1, 0.82, 0)
            end
        else
            row.price:SetText("--")
            row.price:SetTextColor(0.5, 0.5, 0.5)
        end

        -- Timer (nur Verkauft-Tab)
        if isSold then
            row.timer:Show()
            local soldAt = entry.soldAt or 0
            local remaining = MAIL_DELAY - (now - soldAt)
            row.timer:SetText(FormatTimer(remaining))
            if remaining <= 0 then
                row.timer:SetTextColor(0.4, 1, 0.4)
            else
                row.timer:SetTextColor(1, 0.6, 0.2)
            end
        else
            row.timer:Hide()
        end

        -- Summe berechnen
        local copper = entry.buyout or 0
        if copper > 0 then
            totalCopper = totalCopper + copper
        end
    end

    if AHSalesLogFrame then
        if AHSalesLogFrame.countLabel then
            AHSalesLogFrame.countLabel:SetText(count .. " Eintr.")
        end
        if AHSalesLogFrame.sumLabel then
            if totalCopper > 0 then
                AHSalesLogFrame.sumLabel:SetText("Summe: " .. FormatMoney(totalCopper))
                if isSold then
                    AHSalesLogFrame.sumLabel:SetTextColor(0.4, 1, 0.4)
                else
                    AHSalesLogFrame.sumLabel:SetTextColor(1, 0.82, 0)
                end
            else
                AHSalesLogFrame.sumLabel:SetText("")
            end
        end
    end
end

-- ============================================================
-- Timer-Update: aktualisiert die Timer-Spalte jede Sekunde
-- ============================================================

local timerFrame = CreateFrame("Frame")
local timerElapsed = 0
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed < 1 then return end
    timerElapsed = 0

    if not AHSalesLogFrame or not AHSalesLogFrame:IsShown() then return end
    if activeTab ~= "sold" then return end

    local now = time()
    local entries = AHSalesLogDB.entries
    for i, entry in ipairs(entries) do
        local row = rowFrames[i]
        if row and row:IsShown() and row.timer then
            local soldAt = entry.soldAt or 0
            local remaining = MAIL_DELAY - (now - soldAt)
            row.timer:SetText(FormatTimer(remaining))
            if remaining <= 0 then
                row.timer:SetTextColor(0.4, 1, 0.4)
            else
                row.timer:SetTextColor(1, 0.6, 0.2)
            end
        end
    end
end)

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
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("NEW_AUCTION_UPDATE")

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

        SLASH_AHSALESLOG1 = "/ahlog"
        SLASH_AHSALESLOG2 = "/ahsaleslog"
        SlashCmdList["AHSALESLOG"] = ToggleFrame

        SLASH_AHSALESLOGTEST1 = "/ahlogtest"
        SlashCmdList["AHSALESLOGTEST"] = function()
            table.insert(AHSalesLogDB.pendingAuctions, 1, {
                item     = "Schattenpanzerhelm",
                buyout   = 53210,
                priceStr = "5g 32s 10c",
                count    = 1,
                posted   = time(),
                time     = GetTimestamp(),
            })
            local priceStr, copper = FindPendingPrice("Schattenpanzerhelm")
            AddEntry("Schattenpanzerhelm", priceStr, copper)
            print("|cff00ff00AHSalesLog:|r Testeintrag (Eingestellt -> Verkauft).")
        end

        SLASH_AHSALESLOGTEST2 = "/ahlogtest2"
        SlashCmdList["AHSALESLOGTEST2"] = function()
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
            print("|cff00ff00AHSalesLog:|r Testeintrag im 'Eingestellt'-Tab.")
        end

        SLASH_AHSALESLOGDEBUG1 = "/ahlogdebug"
        SlashCmdList["AHSALESLOGDEBUG"] = function()
            print("|cff00ff00AHSalesLog Debug:|r")
            print("  Version: " .. ADDON_VERSION)
            print("  AH offen: " .. (ahIsOpen and "ja" or "nein"))
            print("  GetAuctionSellItemInfo: " .. (GetAuctionSellItemInfo and "vorhanden" or "|cffff0000nicht gefunden|r"))
            print("  BuyoutPrice Frame: " .. (BuyoutPrice and "vorhanden" or "|cffff0000nicht gefunden|r"))
            print("  Sell-Slot Item: " .. (pendingSellName or "leer"))
            print("  Gespeicherter Buyout: " .. FormatMoney(pendingSellBuyout))
            print("  Auctionator: " .. (Auctionator and Auctionator.Selling and "erkannt" or "nicht vorhanden"))
            print("  Pending Auctions: " .. #AHSalesLogDB.pendingAuctions)
            print("  Sold Entries: " .. #AHSalesLogDB.entries)
            if GetAuctionSellItemInfo then
                local n = GetAuctionSellItemInfo()
                print("  Slot LIVE: " .. (n or "leer"))
            end
            if BuyoutPrice and MoneyInputFrame_GetCopper then
                print("  Buyout LIVE: " .. FormatMoney(MoneyInputFrame_GetCopper(BuyoutPrice) or 0))
            end
        end

        local atrLoaded = TryRegisterAuctionator()
        if atrLoaded then
            print("|cff00ff00AHSalesLog|r Auctionator erkannt.")
        end

        print("|cff00ff00AHSalesLog|r v" .. ADDON_VERSION .. " geladen.  /ahlog  /ahlogdebug")

    elseif event == "AUCTION_HOUSE_SHOW" then
        ahIsOpen = true
        pollFrame:Show()
        -- Zweiter Versuch: Auctionator könnte nach uns geladen worden sein
        if lastAuctionatorPostTime == 0 then
            TryRegisterAuctionator()
        end
        pendingSellName  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0

    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahIsOpen = false
        pollFrame:Hide()
        pendingSellName  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0

    elseif event == "NEW_AUCTION_UPDATE" then
        OnAuctionSlotChanged()

    elseif event == "MAIL_INBOX_UPDATE" then
        ScanMailbox()
    end
end)
