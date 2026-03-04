-- AHSalesLog.lua
-- Protokolliert Auktionshaus-Verkäufe aus System-Chat-Nachrichten
-- Interface: TBC Classic Anniversary

-- ============================================================
-- Konstanten & Hilfsvariablen
-- ============================================================

local ADDON_NAME = "AHSalesLog"
local MAX_ENTRIES = 200
local debugMode   = false  -- per /ahlogdebug ein-/ausschalten

-- Patterns für die FORMATIERTE Chat-Nachricht (inkl. Itemname).
-- Das Chat-Frame fügt den Itemnamen erst beim Rendern hinzu – daher nutzen wir
-- ChatFrame_AddMessageEventFilter statt dem rohen CHAT_MSG_SYSTEM-Event.
-- Umlaute als "." um Kodierungsprobleme zu umgehen.
local PATTERNS_SOLD = {
    -- Aus WoW-Global-String (automatisch lokalisiert, falls vorhanden)
    ERR_AUCTION_SOLD_S and string.gsub(ERR_AUCTION_SOLD_S, "%%s", "(.+)") or nil,
    -- DE TBC Anniversary: "...gefunden: Item"
    "Es wurde ein K.ufer f.r Eure Auktion gefunden: (.+)",
    -- DE älteres Format: "...von Item gefunden."
    "Ein K.ufer wurde f.r .* Auktion von (.+) gefunden",
    -- EN Format
    "A buyer has been found for your auction of (.+)",
}

-- Trigger-Patterns (ohne Itemname) als letzter Fallback
local PATTERNS_TRIGGER = {
    "Es wurde ein K.ufer f.r Eure Auktion gefunden",
    "A buyer has been found for your auction",
}
local unseenCount = 0    -- Badge-Zähler Minimap
local minimapBtn  = nil  -- forward declare

-- Spaltenbreiten
local COL_TS    = 80
local COL_ITEM  = 185
local COL_PRICE = 95

local FRAME_WIDTH  = 400
local FRAME_HEIGHT = 320
local ROW_HEIGHT   = 18
local HEADER_H     = 16
local PAD          = 8

local AHSalesLogFrame = nil
local scrollChild     = nil
local rowFrames       = {}

-- ============================================================
-- SavedVariables initialisieren
-- ============================================================

local function InitDB()
    if not AHSalesLogDB then AHSalesLogDB = {} end
    if not AHSalesLogDB.entries      then AHSalesLogDB.entries      = {}                           end
    if not AHSalesLogDB.framePos     then AHSalesLogDB.framePos     = { point="CENTER", x=0, y=0 } end
    if not AHSalesLogDB.minimapAngle then AHSalesLogDB.minimapAngle = 225                          end
end

local function GetTimestamp()
    return date("%d.%m. %H:%M")
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
-- Eintrag hinzufügen
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

-- ============================================================
-- Item-Farb-Codes aus einem String entfernen
-- ============================================================

local function StripColors(s)
    return s:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|h%[(.-)%]|h", "%1")
             :gsub("|[Hhr].-|h", "")
             :gsub("|r", "")
             :gsub("%.$", "")
             :match("^%s*(.-)%s*$")
end

-- ============================================================
-- Chat-Event-Handler
-- ============================================================

-- ChatFrame-Filter: empfängt die FORMATIERTE Nachricht (inkl. Itemlinks).
-- Gibt false zurück → Nachricht wird normal angezeigt, wir loggen nur mit.
local function AHSalesLog_ChatFilter(_, _, msg)
    -- Immer printen wenn AH-Schlüsselwort gefunden (unabhängig von debugMode)
    if msg:find("K.ufer") or msg:find("buyer") or msg:find("Auktion") or msg:find("auction") then
        print("|cffff8800[AHLog]|r Filter: len=" .. #msg .. " >> " .. msg)
    end

    -- Versuche Itemname aus der formatierten Nachricht zu extrahieren
    for _, pattern in ipairs(PATTERNS_SOLD) do
        if pattern then
            local item = msg:match(pattern)
            if item then
                AddEntry(StripColors(item), nil)
                return false
            end
        end
    end

    -- Fallback: Trigger erkannt aber kein Itemname → trotzdem loggen
    for _, pattern in ipairs(PATTERNS_TRIGGER) do
        if msg:find(pattern) then
            AddEntry("(Unbekannt)", nil)
            return false
        end
    end

    return false
end

local function OnChatMsgSystem(msg)
    -- Immer printen wenn AH-Schlüsselwort gefunden
    if msg:find("K.ufer") or msg:find("buyer") or msg:find("Auktion") or msg:find("auction") then
        print("|cffaaaaff[AHLog]|r Raw: len=" .. #msg .. " >> " .. msg)
    end
end

-- ============================================================
-- UI: Hauptfenster (BasicFrameTemplateWithInset – funktioniert
--     im modernen Classic-Client; SetColorTexture ebenfalls)
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

    f.TitleText:SetText("AH Sales Log")

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        AHSalesLogDB.framePos = { point = point, x = x, y = y }
    end)

    -- --------------------------------------------------------
    -- Spaltenüberschriften
    -- --------------------------------------------------------
    local headerBg = f:CreateTexture(nil, "BACKGROUND")
    headerBg:SetColorTexture(0, 0, 0, 0.5)
    headerBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD,      -28)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD+20), -28)
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

    -- --------------------------------------------------------
    -- ScrollFrame (unterhalb Header)
    -- --------------------------------------------------------
    local sf = CreateFrame("ScrollFrame", "AHSalesLogScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",  PAD,       -28 - HEADER_H)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 30)

    local sc = CreateFrame("Frame", "AHSalesLogScrollChild", sf)
    -- Breite fest berechnen statt sf:GetWidth() – der ScrollFrame ist beim
    -- ersten Aufruf noch hidden, GetWidth() würde 0 zurückgeben.
    sc:SetWidth(FRAME_WIDTH - PAD - (PAD + 20))  -- = 364
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    scrollChild = sc

    -- --------------------------------------------------------
    -- "Leeren"-Button
    -- --------------------------------------------------------
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 6)
    clearBtn:SetText("Leeren")
    clearBtn:SetScript("OnClick", function()
        AHSalesLogDB.entries = {}
        AHSalesLog_RefreshList()
    end)

    -- Anzahl-Label
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
    local entries = AHSalesLogDB.entries
    local count   = #entries
    print("|cffaaaaff[AHLog]|r RefreshList: " .. count .. " Einträge, scrollChild=" .. tostring(scrollChild ~= nil))

    for _, row in ipairs(rowFrames) do row:Hide() end

    scrollChild:SetHeight(math.max(count * ROW_HEIGHT + 4, 1))

    for i, entry in ipairs(entries) do
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

            -- Tooltip für abgeschnittene Itemnamen
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

        row.fullItem  = entry.item
        row.fullPrice = entry.price
        row.fullTime  = entry.time

        row.ts:SetText(entry.time)
        row.ts:SetTextColor(0.6, 0.6, 0.6)
        row.item:SetText(entry.item)
        row.item:SetTextColor(1, 0.82, 0)
        if entry.price ~= "" then
            row.price:SetText(entry.price)
            row.price:SetTextColor(0.4, 1, 0.4)
        else
            row.price:SetText("–")
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
    local btn = CreateFrame("Button", "AHSalesLogMinimapBtn", Minimap)
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

    -- Badge
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
        GameTooltip:SetText("AH Sales Log", 1, 1, 1)
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
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        InitDB()

        -- Aktive Patterns beim Login ausgeben
        print("|cff00ff00AHSalesLog:|r " .. #PATTERNS_SOLD .. " Patterns geladen.")
        for i, p in ipairs(PATTERNS_SOLD) do
            if p then print("  [" .. i .. "] " .. p) end
        end

        -- ChatFrame-Filter registrieren: empfängt formatierte Nachrichten mit Itemnamen
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", AHSalesLog_ChatFilter)

        CreateMainFrame()
        CreateMinimapButton()

        local pos = AHSalesLogDB.framePos
        AHSalesLogFrame:ClearAllPoints()
        AHSalesLogFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

        -- /ahlog – Fenster öffnen/schließen
        SLASH_AHSALESLOG1 = "/ahlog"
        SLASH_AHSALESLOG2 = "/ahsaleslog"
        SlashCmdList["AHSALESLOG"] = ToggleFrame

        -- /ahlogtest – Testeintrag hinzufügen (UI-Test)
        SLASH_AHSALESLOGTEST1 = "/ahlogtest"
        SlashCmdList["AHSALESLOGTEST"] = function()
            AddEntry("Schattenpanzerhelm", "5 Gold 32 Silber 10 Kupfer")
            print("|cff00ff00AHSalesLog:|r Testeintrag hinzugefügt.")
        end

        -- /ahlogdebug – alle CHAT_MSG_SYSTEM Nachrichten in den Chat ausgeben
        -- (Hilft den echten AH-Verkaufstext zu sehen und Patterns anzupassen)
        SLASH_AHSALESLOGDEBUG1 = "/ahlogdebug"
        SlashCmdList["AHSALESLOGDEBUG"] = function()
            debugMode = not debugMode
            print("|cff00ff00AHSalesLog:|r Debug-Modus " .. (debugMode and "|cff00ff00AN" or "|cffff4444AUS") .. "|r")
        end

        print("|cff00ff00AHSalesLog|r geladen.  /ahlog  /ahlogtest  /ahlogdebug")

    elseif event == "CHAT_MSG_SYSTEM" then
        OnChatMsgSystem(...)
    end
end)
